require 'resque'

Resque.redis.namespace = "resque:partsbuilder"
