require_relative '../rosace'
require_relative 'evaluation_exception'

# Module containing refinements for Ruby classes.
#
# @author AlexieVQ
module Rosace::Refinements

	refine String do

		# Tests if the string is in +lower_snake_case+, i.e. first character is
		# a lower case ASCII letter and following characters (if they exist) are
		# lower case ASCII letters, digits or underscore.
		# @return [true, false] +true+ if the string is in +lower_snake_case+,
		#  +false+ otherwise
		def lower_snake_case?
			self.match?(/^[a-z][a-z0-9_]*$/)
		end

		# Tests if the string is in +UpperCamelCase+, i.e. first character is a
		# capital ASCII letter, and following characters (if they exist) are
		# ASCII letters (whatever case) or digits.
		# @return [true, false] +true+ if the string is in +UpperCamelCase+,
		#  +false+ otherwise
		def upper_camel_case?
			self.match?(/^[A-Z][A-Za-z0-9]*$/)
		end

		# Returns a +UpperCamelCase+ string from a +lower_snake_case+ one.
		# @return [String] string in +UpperCamelCase+
		# @raise [RuntimeError] string is not in +lower_snake_case+
		def camelize
			unless self.lower_snake_case?
				raise "#{self.inspect} is not a lower_snake_case string"
			end
			self.split('_').map { |word| word.capitalize }.join('')
		end

		# Tests if the string represents a valid name for a CSV file.
		# A valid name is a name in the format +lower_snake_case.csv+.
		# @returns [true, false] +true+ if the name is valid, +false+ otherwise
		def valid_csv_file_name?
			parts = self.split('.')
			parts.length == 2 && parts[0].lower_snake_case? && parts[1] == 'csv'
		end

	end

	refine Array do

		# Pick randomly an element of the enumerable.
		# The random choice is weighted by the +weight+ attribute of the
		# elements. If an element does not have a +weight+ attribute, its weight
		# is 1.
		# Any negative weight is considered null.
		# @return [Object, nil] randomly chosen attribute, or +nil+ if the
		#  enumerable is empty or does not have any attribute with a non-null
		#  weight
		def pick
			total_weight = 0
			# @type [Array<(Object, Integer)>]
			array = self.map do |element|
				weight = element.respond_to?(:weight) ? element.weight : 1
				total_weight += weight
				[element, weight]
			end
			return nil if total_weight == 0
			n = rand(total_weight)
			array.each do |element, weight|
				n -= weight
				return element if n < 0
			end
		end

	end

end