class SesQuota < Scout::Plugin
  needs 'json'

  OPTIONS=<<-EOS
    region:
      name: SES Region
      notes: Specify the AWS region
      default: us-east-1
  EOS

  def build_report
    report(quota)
  end

  private

  def quota
    # expects AWS CLI to be available and configured
    JSON.parse(`aws ses get-send-quota --region=#{option(:region)}`)
  rescue
    {}
  end

end
