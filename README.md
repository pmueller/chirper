# Chirper
Chirper is a purposefully insecure app for learning about and practicing web haxxing.
It was originally developed in 2012 for use at [UFSIT](http://ufsit.org/)

## Running Locally
- You need `ruby >= 2.0` and `bundler`
- `bundle install`
- `bundle exec ruby chirper.rb -e production`
- Go to `localhost:4567` in a browser

## Vulnerabilities
There should be 3 exploitable vulnerablities in total:
- 2 XSS
- 1 CSRF

If you're able to find more then open an issue on this repo and tell me how you did it!

It also has weak authentication (MD5 without a salt). Combined with one of the other vulnerabilites
this could lead to stealing of anyone's account and reversal of plaintext passwords.
