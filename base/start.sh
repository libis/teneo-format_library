#!/bin/env bash

case $1 in
  bundle)
    "$@"
    ;;
  *)
    bundle exec "$@"
    ;;
esac
