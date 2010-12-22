# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_readability_service_session',
  :secret      => '8d201051a4264518ab5da1bb3ee5b013e9d3d074ce6a514c717d9ac9721afdb6bbf770cb1539e63457bc39d7fb2e777fea010b17ec7f751837329809d59f94d1'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
