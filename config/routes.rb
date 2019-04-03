# this not only organizes the routes, but also ensures they're only included
# once (via ruby require behavior), because having two separate engines in the
# gem can cause routes to be parsed twice and double up
require_relative 'routes/engine'
require_relative 'routes/admin'
