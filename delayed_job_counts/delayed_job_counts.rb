class DelayedJobCounts < Scout::Plugin
  needs 'mysql2'

  OPTIONS=<<-EOS
    user:
      name: MySQL username
      notes: Specify the username to connect with
      default: root
    password:
      name: MySQL password
      notes: Specify the password to connect with
      attributes: password
    host:
      name: MySQL host
      notes: Specify something other than 'localhost' to connect via TCP
      default: localhost
    port:
      name: MySQL port
      notes: Specify the port to connect to MySQL with (if nonstandard)
    socket:
      name: MySQL socket
      notes: Specify the location of the MySQL socket
    database:
      name: MySQL database
      notes: Specify the default database to connect to
    EOS

  def build_report
    report(count_by_job)
  end

  private

  JOB_OBJECT_REGEX = /\!ruby\/object\:([^\s]+).*\!ruby\/class '([^\s]+)'.*method_name: :([^\s]+)/m
  JOB_STRUCT_REGEX = /\!ruby\/struct\:([^\s]+)/
  JOB_NAMES_KEY = :delayed_job_names

  def count_by_job
    counts = load_jobs.reduce(known_jobs) do |results, job|
      klass = job_klass(job)
      name = job[:failed_at] ? "FAILED: #{klass}" : "QUEUED: #{klass}"

      results[name] ||= 0
      results[name] += 1
      results
    end

    remember_jobs(counts.keys)

    counts
  end

  def load_jobs
    @load_jobs ||= client.query("SELECT * FROM delayed_jobs", :symbolize_keys => true, :stream => true)
  end

  def client
    @client ||= begin
      params = {}
      params[:username] = option(:user) || 'root'
      params[:password] = option(:password)
      params[:host] = option(:host)
      params[:port] = option(:port)
      params[:socket] = option(:socket)
      params[:database] = option(:database)
      params.delete_if { |_,v| v.nil? }

      Mysql2::Client.new(params)
    end
  end

  def job_klass(job)
    if JOB_OBJECT_REGEX.match(job[:handler])
      "#{$1} - #{$2}##{$3}"
    elsif JOB_STRUCT_REGEX.match(job[:handler])
      $1
    else
      "unknown"
    end
  end

  def known_jobs
    (memory(JOB_NAMES_KEY) || []).reduce({}) do |result, name|
      result[name] ||= 0
      result
    end
  end

  def remember_jobs(names)
    remember(JOB_NAMES_KEY, names)
  end

end
