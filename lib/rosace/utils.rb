require_relative '../rosace'

# Common functions used in the project.
#
# @author AlexieVQ
module Rosace::Utils
	# Converts +object+ to given +target_type+ using its defined +method+.
	#
	# @param object object to convert
	# @param method [#to_sym] +object+’s conversion method
	# @param target_type [#to_s] target type’s name (only used in error
	#   messages)
	# @return Converted +object+
	# @raise [TypeError] no conversion method for +object+
	def self.convert(object, method, target_type)
		begin
			object = object.send(method.to_sym)
		rescue NoMethodError
			raise TypeError,
				"no implicit conversion of #{object.class} into #{target_type}"
		end
		return object
	end

	# Converts +object+ to String using its +#to_str+ method
	#
	# @param object [#to_str] object to convert
	# @return [String] String from +object+
	# @raise [TypeError] +object+ has no +#to_str+ method
	def self.str(object)
		self.convert(object, :to_str, "String")
	end

	# Converts +object+ to Symbol using its +#to_sym+ method
	#
	# @param object [#to_sym] object to convert
	# @return [Symbol] Symbol from +object+
	# @raise [TypeError] +object+ has no +#to_sym+ method
	def self.sym(object)
		self.convert(object, :to_sym, "Symbol")
	end

	# Converts +object+ to Integer using its +#to_int+ method
	#
	# @param object [#to_int] object to convert
	# @return [Integer] Integer value of +object+
	# @raise [TypeError] +object+ has no +#to_int+ method
	def self.int(object)
		self.convert(object, :to_int, "Integer")
	end

	# Checks if +object+ is of given +type+.
	#
	# Raises a +TypeError+ if +object+ is not of given +type+.
	#
	# @param object object to check
	# @param type [Class] expected type
	# @raise [TypeError] +object+ is not of given +type+.
	def self.check_type(object, type)
		unless object.kind_of?(type)
			raise TypeError,
				"wrong type (#{type} expected, #{object.class} given)"
		end
		return nil
	end
end