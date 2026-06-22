#!/bin/env bash

if compgen -G "/app/*.gem" > /dev/null; then
  for f in /app/*.gem
  do
    gem unpack $f --target /app
  done
  bundle install
fi

case $1 in
  bundle)
    "$@"
    ;;
  *)
    bundle exec "$@"
    ;;
esac
