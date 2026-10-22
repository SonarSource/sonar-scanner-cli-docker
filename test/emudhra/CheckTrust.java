import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyStore;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import javax.net.ssl.TrustManagerFactory;
import javax.net.ssl.X509TrustManager;

class CheckTrust {
  private static X509TrustManager trustManager(KeyStore store) throws Exception {
    var factory = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
    factory.init(store);
    for (var manager : factory.getTrustManagers()) {
      if (manager instanceof X509TrustManager x509) {
        return x509;
      }
    }
    throw new IllegalStateException("No X509 trust manager available");
  }

  public static void main(String[] args) {
    try {
      System.exit(check(Path.of(args[0])));
    } catch (Exception error) {
      System.err.println("ERROR: Java trust validation was inconclusive: " + error);
      System.exit(2);
    }
  }

  private static int check(Path directory) throws Exception {
    var certificates = CertificateFactory.getInstance("X.509");
    var controls = KeyStore.getInstance(KeyStore.getDefaultType());
    controls.load(null, null);
    try (var input = Files.newInputStream(directory.resolve("control-root.pem"))) {
      int index = 0;
      for (var root : certificates.generateCertificates(input)) {
        controls.setCertificateEntry("control-" + index++, root);
      }
    }
    var positiveControl = trustManager(controls);
    try (var input = Files.newInputStream(directory.resolve("control-chain.pem"))) {
      var chain = certificates.generateCertificates(input).toArray(X509Certificate[]::new);
      positiveControl.checkServerTrusted(chain, "ECDHE_ECDSA");
    }
    var actual = trustManager(null);
    int accepted = 0;
    try (var files = Files.list(directory.resolve("chains"))) {
      var chains = files.filter(p -> p.toString().endsWith(".pem")).sorted().toList();
      if (chains.size() != 12) {
        throw new IllegalStateException("Expected 12 TLS chains");
      }
      for (var path : chains) {
        X509Certificate[] chain;
        try (var input = Files.newInputStream(path)) {
          chain = certificates.generateCertificates(input).toArray(X509Certificate[]::new);
        }
        // OpenSSL verifies fixture signatures against the original roots in
        // the calling Python check. Check expiry here too. The native Java
        // positive control uses an unrelated CA: an updated JDK may correctly
        // block the eMudhra intermediates even with their roots explicitly trusted.
        for (var certificate : chain) {
          certificate.checkValidity();
        }
        try {
          actual.checkServerTrusted(chain, "ECDHE_ECDSA");
          System.out.println("[FAIL] Java: still trusts " + path.getFileName());
          accepted++;
        } catch (CertificateException expected) {
          // The real trust manager rejected a chain valid under the control roots.
        }
      }
      System.out.println("Java " + System.getProperty("java.version") + ": accepted "
        + accepted + "/" + chains.size() + " compromised chains");
    }
    return accepted == 0 ? 0 : 1;
  }
}
