# frozen_string_literal: true

require 'discordrb'
require 'rss'
require 'sqlite3'

# 봇 토큰과 클라이언트 ID를 환경 변수에서 불러옵니다.
# 실제 운영 시에는 환경 변수나 다른 보안 방법을 사용하는 것이 좋습니다.
bot_token = ENV['DISCORD_BOT_TOKEN']
client_id = ENV['DISCORD_CLIENT_ID']

# 데이터베이스 설정
DB = SQLite3::Database.new 'blogs.db'
DB.execute <<~SQL
  CREATE TABLE IF NOT EXISTS blogs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    url TEXT NOT NULL UNIQUE,
    last_post_guid TEXT
  );
SQL

# 봇 생성
bot = Discordrb::Commands::CommandBot.new(
  token: bot_token,
  client_id: client_id,
  prefix: '!'
)

puts "봇 서버 URL: #{bot.invite_url}"

# 블로그 등록 명령어
bot.command(:등록) do |event, url|
  unless url&.start_with?('http')
    event.respond '올바른 URL을 입력해주세요. (예: `!등록 https://example.com/feed`)'
    next
  end

  begin
    DB.execute('INSERT INTO blogs (url) VALUES (?)', url)
    event.respond "블로그가 성공적으로 등록되었습니다: #{url}"
  rescue SQLite3::ConstraintException
    event.respond '이미 등록된 블로그 주소입니다.'
  rescue StandardError => e
    event.respond "등록 중 오류가 발생했습니다: #{e.message}"
  end
end

# 등록된 블로그 목록 확인 명령어
bot.command(:목록) do |event|
  blogs = DB.execute('SELECT url FROM blogs')
  if blogs.empty?
    event.respond '등록된 블로그가 없습니다.'
  else
    response = "**등록된 블로그 목록**\n"
    blogs.each_with_index do |row, index|
      response += "#{index + 1}. #{row[0]}\n"
    end
    event.respond response
  end
end

# 블로그 삭제 명령어
bot.command(:삭제) do |event, url|
    unless url&.start_with?('http')
        event.respond '올바른 URL을 입력해주세요. (예: `!삭제 https://example.com/feed`)'
        next
    end

    begin
        DB.execute('DELETE FROM blogs WHERE url = ?', url)
        event.respond "블로그가 성공적으로 삭제되었습니다: #{url}"
    rescue SQLite3::ConstraintException
        event.respond '등록되지 않은 블로그 주소입니다.'
    rescue StandardError => e
        event.respond "삭제 중 오류가 발생했습니다: #{e.message}"
    end
end

# 새 글 확인 및 알림 전송 로직
def check_new_posts(bot)
  loop do
    puts '새 글을 확인합니다...'
    blogs = DB.execute('SELECT id, url, last_post_guid FROM blogs')

    blogs.each do |id, url, last_post_guid|
      begin
        feed = RSS::Parser.parse(URI.open(url).read, false)
        latest_item = feed.items.first

        next unless latest_item

        latest_guid = latest_item.guid&.content || latest_item.link.href

        if latest_guid != last_post_guid
          # 실제 운영 시에는 특정 채널 ID를 사용해야 합니다.
          # 우선은 첫 번째 채널에 알림을 보내도록 설정합니다.
          channel_id = bot.servers.values.first.channels.first.id

          bot.send_message(channel_id, "**새 글 알림**\n**#{feed.channel.title}**\n#{latest_item.title}\n#{latest_item.link.href}")

          DB.execute('UPDATE blogs SET last_post_guid = ? WHERE id = ?', latest_guid, id)
        end
      rescue StandardError => e
        puts "블로그 피드를 확인하는 중 오류가 발생했습니다 (#{url}): #{e.message}"
      end
    end

    # 15분마다 확인
    sleep(900)
  end
end

# 봇이 준비되면 새 글 확인 스레드 시작
bot.ready do
  Thread.new { check_new_posts(bot) }
end

# 봇 실행
bot.run
