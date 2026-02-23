class Wardn < Formula
  desc "Encrypted Bitwarden vault backup and restore using Age encryption"
  homepage "https://github.com/phoggy/wardn"
  url "{URL}"
  sha256 "{SHA256}"
  license "GPL-3.0-only"

{DEPENDS_ON}

  def install
    bin.install "bin/wardn"
    (share/"wardn"/"lib").install Dir["lib/*.sh"]
    (share/"wardn"/"etc").install Dir["etc/*"]
    (share/"wardn").install "rayvn.pkg"
  end

  test do
    system "#{bin}/wardn", "--version"
  end
end
