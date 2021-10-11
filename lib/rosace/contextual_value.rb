require_relative '../rosace'

# An object associating a value to the context in which this value exists.
#
# @author AlexieVQ
class Rosace::ContextualValue

	# @return Stored value
	attr_reader :value

	# @return [Context] Context associated to this value
	attr_reader :context

	# Wraps given value and context in a new ContextualValue.
	# @param value value to wrap
	# @param [Context] context context associated to this value
	# @raise [TypeError] wrong argument types
	def initialize(value, context)
		@value = value
		Rosace::Utils.check_type(context, Rosace::Context)
		@context = context
	end

	# Creates a ContextualValue that wraps an empty String value.
	# @param [Context] context context to wrap
	# @raise [TypeError] wrong argument types
	def self.empty(context)
		new('', context)
	end

end