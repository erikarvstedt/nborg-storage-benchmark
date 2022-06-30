#!/usr/bin/env ruby

BenchmarkRegexp = %r{
  ^\+\ (?<cmd>pgbench_.*?)\n
  .*?
  ^(?<results>scaling\ factor:.*?)\n\n
}xm

def parse_file(path)
  src = File.read(path)
  {
    system: src[/\A.*/, 0],
    tasks: src.scan(BenchmarkRegexp).map { |cmd, results|
      {
        cmd: cmd,
        tps: results[/tps = (.*?) \((?:without initial connection time|excluding connections establishing)\)/, 1].to_f,
        latency_ms: results[/latency average = (.*?) ms/, 1].to_f,
      }
    }
  }
end

def benchmark_to_html(benchmark)
  tasks = benchmark[:tasks].sort_by { |task| -task[:tps] }
  <<~EOF
    <h2>#{benchmark[:system]}</h2>
    <table>
      <tr>
        <th>task</th>
        <th>Transactions per Second</th>
        <th>Average Latency (ms)</th>
      </tr>
      #{tasks.map { |t| task_to_html(t) }.join}
    </table>
  EOF
end

def task_to_html(task)
  <<~EOF
    <tr>
      <td>#{task[:cmd]}</td>
      <td>#{task[:tps].round(2)}</td>
      <td>#{task[:latency_ms].round(2)}</td>
    </tr>
  EOF
end

def create_html(*paths)
  paths.map { |path|
    bm = parse_file(path)
    benchmark_to_html(bm)
  }.join
end

def create_html_all_results
  create_html(*Dir['benchmark*-results'])
end

if __FILE__ == $0
  # pp parse_file("benchmark1-results"); exit
  if ARGV.size > 0
    puts create_html(*ARGV)
  else
    puts create_html_all_results
  end
end
