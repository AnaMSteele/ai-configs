class PlanReviewer < Formula
  desc "Local HTML plan review daemon and CLI for agent comment workflows"
  homepage "https://github.com/adnichols/ai-configs"
  tap_root = File.expand_path("..", __dir__)
  tap_branch = Utils.safe_popen_read("git", "-C", tap_root, "branch", "--show-current").strip
  tap_branch = "main" if tap_branch.empty?
  url "file://#{tap_root}", using: :git, branch: tap_branch
  version "0.1.0"

  depends_on "node"

  def install
    cd "tools/plan-reviewer" do
      system "npm", "ci", "--include=dev"
      system "npx", "tsc"
      system "npm", "prune", "--omit=dev"
      libexec.install Dir["*"]
    end
    bin.install_symlink libexec/"bin/plan-review" => "plan-review"
  end

  service do
    run [opt_bin/"plan-review", "serve", "--host", "0.0.0.0", "--port", "4317", "--db", "#{Dir.home}/.plan-reviewer/plan-reviewer.sqlite"]
    keep_alive true
    log_path var/"log/plan-reviewer.log"
    error_log_path var/"log/plan-reviewer.err.log"
  end

  def caveats
    <<~EOS
      Stop the persistent service with:
        brew services stop plan-reviewer

      Uninstalling the formula does not delete review data. To remove stored
      plans, comments, assets, and watch state manually:
        rm -rf ~/.plan-reviewer
    EOS
  end

  test do
    assert_match "plan-review", shell_output("#{bin}/plan-review --help")
  end
end
