require 'open3'

class PrReview
  def initialize
    @pr_url = ARGV[0]
    raise "No Github URL is provided" if @pr_url.nil? || @pr_url.empty?
  end
end
