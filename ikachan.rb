#!/usr/bin/env ruby
require 'net/http'
require 'uri'

join_url   = ENV['join_url']
notice_url = ENV['notice_url']
channel    = ENV['channel']
job        = ENV['job']
url        = ENV['url']
git_commit = ENV['git_commit']
git_branch = ENV['git_branch']
git_url    = ENV['git_url']

http = Net::HTTP.new(URI(join_url).host, URI(join_url).port)
req = Net::HTTP::Post.new(URI(join_url).path)
req.form_data = { 'channel' => channel }
http.request(req)

http = Net::HTTP.new(URI(url).host, URI(url).port)
req = Net::HTTP::Get.new(URI(url).path + 'api/xml')
res = http.request(req)
xml = res.body

result = xml.match(/<result>(.+?)</)[1]

code = case result
when 'ABORTED' then 8
when 'SUCCESS' then 3
when 'FAILURE' then 4
else nil
end

result = "\x02\x0301,%02d%s\x0f" % [code, result] if code

github = if git_url.include?('github.com')
  git_url.match(/github\.com[:\/](.*)\/(.*)\.git\Z/)
end

pull_request_url = if github && git_branch.include?('origin/pr')
  pull_request_id = git_branch.match(/origin\/pr\/(\d+)\/merge/)[1]
  "https://github.com/#{github[1]}/#{github[2]}/pull/#{pull_request_id}"
end

commit_url = if github && !git_commit.eql?('')
  "https://github.com/#{github[1]}/#{github[2]}/commit/#{git_commit}"
end

message = if pull_request_url
  "Jenkins (%s): %s - %s, pull request: %s" % [job, result, url, pull_request_url]
else if commit_url
  "Jenkins (%s): %s - %s, commit: %s" % [job, result, url, commit_url]
else
  "Jenkins (%s): %s - %s" % [job, result, url]
end

http = Net::HTTP.new(URI(notice_url).host, URI(notice_url).port)
req = Net::HTTP::Post.new(URI(notice_url).path)
req.form_data = { 'channel' => channel, 'message' => message }
http.request(req)
