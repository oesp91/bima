# 베이스 이미지로 공식 Ruby 이미지를 사용합니다.
FROM ruby:3.1-slim

# 컨테이너 내에서 작업 디렉토리를 설정합니다.
WORKDIR /app

# 필요한 시스템 라이브러리를 설치합니다. (sqlite3 gem의 네이티브 확장을 위해)
RUN apt-get update -qq && apt-get install -y build-essential libsqlite3-dev

# Gemfile을 복사하고 의존성을 설치합니다.
COPY Gemfile Gemfile.lock ./
RUN bundle install

# 애플리케이션 코드를 컨테이너에 복사합니다.
COPY . .

# 컨테이너가 시작될 때 실행할 기본 명령어를 설정합니다.
CMD ["ruby", "src/main.rb"]
