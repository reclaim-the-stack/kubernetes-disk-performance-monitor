FROM ruby:3.4.7-slim AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install gems into a project-local path so we can copy them into the final image.
ENV BUNDLE_PATH=/app/vendor/bundle \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_DEPLOYMENT=1

COPY Gemfile Gemfile.lock ./
RUN bundle install && bundle clean --force

COPY main.rb config.ru ./

FROM ruby:3.4.7-slim

WORKDIR /app
ENV BUNDLE_PATH=/app/vendor/bundle \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_DEPLOYMENT=1

COPY --from=builder /app /app

CMD ["bundle", "exec", "puma", "-p", "3000"]
