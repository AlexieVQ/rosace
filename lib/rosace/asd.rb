require 'rattler'
require_relative '../rosace'
require_relative 'messages'
require_relative 'evaluation_exception'
require_relative 'contextual_value'
require_relative 'refinements'

# Abstract syntax definition for the expansion language.
#
# ```
# choice		:= Choice(variant*)
#
# variant		:= Variant(part*)
#
# part			:= choice | optional | text | statement
#
# optional		:= Optional(variant)
#
# text			:= Text(string)
#
# statement		:= Print(expression)
#				 | Assignment(symbol, expression)
#				 | Predicate(symbol)
#
# expression	:= MethodCall(expression, symbol, argument*)
#				 | SymbolReading (symbol)
#				 | FunctionCall(symbol, argument*)
#				 | Picker(symbol, argument*)
#				 | AssignmentExpr(assignment)
#				 | Reference(symbol, id)
# ```
#
# @private
module Rosace::ASD

	MAX_ATTEMPTS = 5

	using Rosace::Refinements

	# A node of the syntactic tree.
	class Node

		# @return [Symbol] Name of the rule where this node is defined.
		attr_reader :rule_name

		# @return [Integer] Id of the entity where this node is defined.
		attr_reader :entity_id

		# @return [Symbol] Name of the attribute where this node is defined.
		attr_reader :attribute

		# Sets where this node is defined.
		# @param rule_name [Symbol] Name of the rule where this node is defined.
		# @param entity_id [Integer] Id of the entity where this node is
		#  defined.
		# @param attribute [Symbol] Name of the attribute where this node is
		#  defined.
		# @return [void]
		def set_location(rule_name, entity_id, attribute)
			@rule_name = rule_name
			@entity_id = entity_id
			@attribute = attribute
			nil
		end

		# Verifies this node.
		# @param [Context] context verification context
		# @return [Array<Message>] generated error and waring messages
		def verify(context)
			[]
		end

		# Whether evaluation output will be the same if the context is the same.
		# @return [Boolean] +true+ if the evaluation output if the same if the
		#  context is the same.
		def deterministic?
			true
		end

		# @return [String] Code representation of this node
		def to_s
			super
		end

		def ==(o)
			self.class == o.class
		end

		# Expands this node.
		# @param [Context] context expansion context
		# @return Evaluation result
		# @raise [EvaluationException] exception during expansion
		def eval(context)
			raise Rosace::EvaluationException, "No evaluation for node #{self}"
		end

	end

	# Part of a {Variant}.
	class Part < Node

		# Expands this node.
		# @param [Context] context expansion context
		# @return [String] output String
		# @raise [EvaluationException] exception during expansion
		def eval(context)
			""
		end

	end
	
	# A random choice between several {Variants}s.
	class Choice < Part
		
		# @return [Array<Variant>] Variants to pick
		attr_reader :variants
		
		# Creates a choice with given +variants+.
		# @param [Array<Variant>] variants variants to pick
		def initialize(variants)
			@variants = variants
		end

		def set_location(*args)
			super(*args)
			variants.each { |variant| variant.set_location *args }
			nil
		end

		def verify(context)
			variants.reduce(super(context)) do |messages, variant|
				messages + variant.verify(context)
			end
		end

		def eval(context)
			list = variants.sort { |v1, v2| 1 - 2 * rand(2) }
			parent = context
			begin
				context = parent.send(:child)
				# @type [Variant]
				res = list.pop.eval(context)
				context.send(:write_to_parent, local: true)
				res
			rescue Rosace::EvaluationException => e
				if list.empty?
					raise e
				else
					context.log(e)
					retry
				end
			end
		end

		def deterministic?
			variants.all? { |variant| variant.deterministic? }
		end

		def to_s
			variants.map { |variant| variant.to_s }.join('|')
		end

		def ==(o)
			super(o) && self.variants == o.variants
		end

	end

	# A variant of a {Choice}.
	class Variant < Node
		
		# @return [Array<Part>] parts of this variant
		attr_reader :parts

		# Creates a variant with given +parts+.
		# @param [Array<Part>] parts parts of this variant
		def initialize(parts)
			@parts = parts
		end

		def set_location(*args)
			super(*args)
			parts.each { |part| part.set_location *args }
			nil
		end

		def verify(context)
			parts.reduce(super(context)) do |messages, part|
				messages + part.verify(context)
			end
		end

		def to_s
			parts.map do |part|
				s = ""
				s += "(" if part.is_a?(Rosace::ASD::Choice)
				s += part.to_s
				s += ")" if part.is_a?(Rosace::ASD::Choice)
				s
			end.join('')
		end

		def deterministic?
			parts.all? { |part| part.deterministic? }
		end

		def ==(o)
			super(o) && self.parts == o.parts
		end

		# Expands this node.
		# @param [Context] context expansion context
		# @return [String] output String
		# @raise [EvaluationException] exception during expansion
		def eval(context)
			Rosace::ASD.eval_sequence(parts, context).join("")
		end

	end

	# A node randomly printing or not its content.
	class Optional < Part
		
		# @return [Choice] Choice to print
		attr_reader :choice

		# Creates an optional.
		# @param choice [Choice] choice ot print
		def initialize(choice)
			@choice = choice
		end

		def set_location(*args)
			super(*args)
			choice.set_location *args
			nil
		end

		def verify(context)
			choice.verify(context)
		end

		def to_s
			"(#{choice})?"
		end

		def ==(o)
			super(o) && self.choice == o.choice
		end

		def deterministic?
			choice.deterministic?
		end

		def eval(context)
			parent = context
			begin
				context = parent.send(:child)
				res = rand(2) == 1 ? choice.eval(context) : ""
				context.send(:write_to_parent, local: true)
				res
			rescue Rosace::EvaluationException => e
				context.log(e)
				""
			end
		end

	end

	# A simple text without expansion node.
	class Text < Part
		
		# @return [String] text value
		attr_reader :text

		# Creates a text node.
		# @param [String] text value
		def initialize(text)
			@text = text
		end

		def to_s
			text.clone
		end

		def deterministic?
			true
		end

		def ==(o)
			super(o) && self.text == o.text
		end

		def eval(context)
			text.clone
		end

	end

	# An expansion statement.
	class Statement < Part; end

	# A print statement.
	class Print < Statement
		
		# @return [Expression] expression whose value will be printed
		attr_reader :expression

		# Creates a print statement.
		# @param [Expression] expression expression whose value will be printed
		def initialize(expression)
			@expression = expression
		end

		def set_location(*args)
			super(*args)
			expression.set_location *args
			nil
		end

		def verify(context)
			super(context) + expression.verify(context)
		end

		def to_s
			"{ #{expression} }"
		end

		def deterministic?
			expression.deterministic?
		end

		def ==(o)
			super(o) && self.expression == o.expression
		end

		def eval(context)
			out = expression.eval(context)
			eval_value(out, context)
		end

		private

		def eval_value(value, context)
			if value.respond_to?(:to_str)
				value.to_str
			elsif value.respond_to?(:value)
				eval_value(value.value, context)
			else
				value.to_s
			end
		end

	end

	# An assignment.
	class Assignment < Statement
		
		# @return [Symbol] symbol of the variable
		attr_reader :symbol

		# @return [Expression] expression whose value will be assigned
		attr_reader :expression

		# @return ["=", "||="] assignment operator
		attr_reader :operator

		# Creates an assignment.
		# @param symbol [Symbol] symbol of the variable
		# @param operator ["=", "||="] assignment operator
		# @param expression [Expression] expression whose value will be assigned
		def initialize(symbol, operator, expression)
			@symbol = symbol
			@operator = operator
			@expression = expression
		end

		def set_location(*args)
			super(*args)
			expression.set_location *args
			nil
		end

		def verify(context)
			messages = super(context) + expression.verify(context)
			if symbol == :self
				messages << Rosace::ErrorMessage.new(
					"\"self\" is a reserved keyword",
					rule_name, entity_id, attribute
				)
			elsif context.generator.functions.key?(symbol)
				messages << Rosace::ErrorMessage.new(
					"\"#{symbol}\" is the name of a function",
					rule_name, entity_id, attribute
				)
			end
			messages
		end

		def to_s
			"{ #{symbol} #{operator} #{expression} }"
		end

		def ==(o)
			super(o) &&
				self.symbol == o.symbol &&
				self.operator == o.operator &&
				self.expression == o.expression
		end

		def deterministic?
			expression.deterministic?
		end

		def eval(context)
			unless operator == "||=" && context.variable?(symbol)
				context.store_variable!(symbol, expression.eval(context))
			end
			super(context)
		end

	end

	# A predicate testing the existence of a variable.
	class Predicate < Statement
		
		# @return [Symbol] variable to test
		attr_reader :symbol

		# Creates a predicate for given +symbol+.
		# @param [Symbol] symbol symbol to test
		def initialize(symbol)
			@symbol = symbol
		end

		def to_s
			"{ #{symbol}! }"
		end

		def deterministic?
			true
		end

		def ==(o)
			super(o) && self.symbol == o.symbol
		end

		def eval(context)
			if context.variable?(symbol)
				super(context)
			else
				raise Rosace::EvaluationException,
					"#{rule_name}[#{entity_id}]##{attribute}: No variable " +
					"named \"#{symbol}\" in current context"
			end
		end

	end

	# An assignment on an object’s attribute.
	class AttrSetter < Statement
		
		# @return [Expression] Object receiving this assignment
		attr_reader :receiver

		# @return [Symbol] Name of the attribute to assign
		attr_reader :symbol

		# @return [Expression] Assigned value
		attr_reader :value

		# @return ["=", "||="] Assignment operator
		attr_reader :operator

		# @return Result of the value’s evaluation
		attr_reader :result
		
		# Creates an attribute setter.
		# @param receiver [Expression] Object receiving this assignment
		# @param symbol [Symbol] Name of the attribute to assign
		# @param operator ["=", "||="] Assignment operator
		# @param value [Expression] Value to assign
		def initialize(receiver, symbol, operator, value)
			@receiver = receiver
			@symbol = symbol
			@operator = operator
			@value = value
		end

		def set_location(*args)
			super(*args)
			receiver.set_location(*args)
			value.set_location(*args)
			nil
		end

		def verify(context)
			super(context) + receiver.verify(context) + value.verify(context)
		end

		def to_s
			"{ #{receiver}.#{symbol} #{operator} #{value} }"
		end

		def ==(o)
			super(o) &&
				self.receiver == o.receiver &&
				self.symbol == o.symbol &&
				self.operator == o.operator &&
				self.value == o.value
		end

		def deterministic?
			receiver.deterministic? && value.deterministic?
		end

		def eval(context)
			receiver_out = receiver.eval(context)
			setter = "#{symbol.id2name}=".to_sym
			variable = "@#{symbol.id2name}".to_sym
			unless operator == "||=" &&
				receiver_out.respond_to?(symbol) &&
				receiver_out.send(symbol)
				@result = value.eval(context)
				if receiver_out.respond_to?(setter)
					receiver_out.send(setter, result)
				elsif receiver_out.respond_to?(symbol) ||
					receiver_out.instance_variable_defined?(variable)
					raise Rosace::EvaluationException,
						"#{rule_name}[#{entity_id}]##{attribute}: attribute " +
						"\"#{symbol}\" already defined for object " +
						receiver_out.inspect
				else
					receiver_out.instance_variable_set(variable, result)
					receiver_out.define_singleton_method(symbol) do
						self.instance_variable_get(variable)
					end
				end
			else
				@result = receiver_out.send(symbol)
			end
			super(context)
		end

	end

	# An expression, returning a value.
	class Expression < Node

		private

		# Ensures that given value is not +nil+.
		# @param value Value to check
		# @return Given value
		# @raise [EvaluationException] Given value is +nil+
		def ensure_value(value)
			if value.nil?
				raise Rosace::EvaluationException,
					"#{rule_name}[#{entity_id}]##{attribute}: nil value " +
					"returned by expression \"#{self}\""
			end
			value
		end
	end

	# A method call on an expression
	class MethodCall < Expression
		
		# @return [Expression] expression on which the method is called
		attr_reader :expression

		# @return [Symbol] name of the method
		attr_reader :symbol

		# @return [Array<Part>] arguments arguments of the method call
		attr_reader :arguments

		# Creates a method call.
		# @param [Expression] expression expression on which the method is
		#  called
		# @param [Symbol] symbol name of the method
		# @param [Array<Part>] arguments arguments of the method call
		def initialize(expression, symbol, arguments)
			@expression = expression
			@symbol = symbol
			@arguments = arguments
		end

		def set_location(*args)
			super(*args)
			expression.set_location *args
			arguments.each { |argument| argument.set_location *args }
			nil
		end

		def verify(context)
			arguments.reduce(
				super(context) + expression.verify(context)
			) do |messages, argument|
				messages + argument.verify(context)
			end
		end

		def to_s
			string = "#{expression}.#{symbol}"
			unless arguments.empty?
				string += "(#{arguments.map { |arg| arg.to_s }.join(',')})"
			end
			string
		end

		def ==(o)
			super(o) &&
				self.expression == o.expression &&
				self.symbol == o.symbol &&
				self.arguments == o.arguments
		end

		def deterministic?
			false
		end

		def eval(context)
			outs = Rosace::ASD.eval_sequence([expression] + arguments, context)
			expr_out = outs.first
			args = outs[1, outs.length]
			ensure_value(expr_out.send(symbol, *args))
		end

	end

	# A reading of a variable, a function call without arguments or the +self+
	# keyword.
	class SymbolReading  < Expression
		
		# @return [Symbol] Symbol
		attr_reader :symbol

		# Creates a symbol reading of given name
		# @param [Symbol] Symbol to read
		def initialize(symbol)
			@symbol = symbol
			# @type [Boolean]
			@deterministic = false
		end

		def to_s
			symbol.to_s
		end

		def deterministic?
			@deterministic
		end

		def verify(context)
			messages = super(context)
			function = context.generator.functions[symbol]
			if function
				if function.min_arity > 0
					error_class = function.min_arity == 1 ?
						Rosace::WarningMessage :
						Rosace::ErrorMessage
					messages << error_class.new(
						"Wrong number of arguments for \"#{symbol}\" " +
							"function (#{function.min_arity} expected, 0 " +
							"given)",
						rule_name,
						entity_id,
						attribute
					)
				end
			else
				@deterministic = true
			end
			messages
		end

		def ==(o)
			super(o) && self.symbol == o.symbol
		end

		def eval(context)
			ensure_value(if symbol == :self
				context.entity(rule_name, entity_id)
			elsif context.generator.functions.key?(symbol)
				out = context.generator.functions[symbol].
						call(Rosace::ContextualValue.empty(
						context.send(:child)))
				out.context.send(:write_to_parent, local: true)
				out.value
			else
				context.variable(symbol)
			end)
		end

	end

	# A function call.
	class FunctionCall < Expression
		
		# @return [Symbol] name of the function
		attr_reader :symbol

		# @return [Array<Part>] arguments of the function call
		attr_reader :arguments

		# Creates a function call.
		# @param [Symbol] symbol name of the function
		# @param [Array<Part>] arguments arguments of the function call
		def initialize(symbol, arguments)
			@symbol = symbol
			@arguments = arguments
		end

		def set_location(*args)
			super(*args)
			arguments.each { |argument| argument.set_location *args }
			nil
		end

		def verify(context)
			messages = super(context)
			if context.generator.functions.key?(symbol)
				f = context.generator.functions[symbol]
				if arguments.length < f.min_arity
					messages << Rosace::ErrorMessage.new(
						"Too few arguments for function \"#{symbol}\" (" +
							"#{f.min_arity} expected, #{arguments.length} " +
							"given)",
						rule_name,
						entity_id,
						attribute
					)
				elsif arguments.length > f.max_arity
					messages << Rosace::ErrorMessage.new(
						"Too many arguments for function \"#{symbol}\" (" +
							"#{f.max_arity} expected, #{arguments.length} " +
							"given)",
						rule_name,
						entity_id,
						attribute
					)
				end
			else
				messages << Rosace::ErrorMessage.new(
					"No function named \"#{symbol}\"",
					rule_name,
					entity_id,
					attribute
				)
			end
			arguments.reduce(messages) do |messages, argument|
				messages + argument.verify(context)
			end
		end

		def to_s
			string = symbol.to_s
			unless arguments.empty?
				string += "(#{arguments.map { |arg| arg.to_s }.join(',')})"
			end
			string
		end

		def ==(o)
			super(o) && 
				self.symbol == o.symbol &&
				self.arguments == o.arguments
		end

		def deterministic?
			false
		end

		def eval(context)
			parent = context
			context = parent.send(:child)
			f = context.generator.functions[symbol]
			args = f.type == :sequential ?
				Rosace::ASD.eval_sequence(arguments, context).map do |arg|
					Rosace::ContextualValue.new(arg, context)
				end :
				arguments.map do |arg|
					arg_context = parent.send(:child)
					Rosace::ContextualValue.new(
						arg.eval(arg_context),
						arg_context
					)
				end
			out = f.call(*args)
			out.context.send(:write_to_parent, local: true)
			ensure_value(out.value)
		end

	end

	# An expression picking an entity from a rule.
	class Picker < Expression
		
		# @return [Symbol] name of the rule
		attr_reader :symbol

		# @return [Array<Part>] arguments for this picker.
		attr_reader :arguments

		# Creates a picker.
		# @param [Symbol] symbol name of the rule
		# @param [Array<Part>] arguments arguments for this picker
		def initialize(symbol, arguments)
			@symbol = symbol
			@arguments = arguments
		end

		def set_location(*args)
			super(*args)
			arguments.each { |argument| argument.set_location *args }
			nil
		end

		def verify(context)
			messages = super(context)
			if context.generator.rules.key?(symbol)
				rule = context.generator.rules[symbol]
				arity = rule.instance_method(:pick?).arity
				min_arity = arity >= 0 ? arity : (arity + 1) * -1
				max_arity = arity >= 0 ? arity : Float::INFINITY
				if arguments.length < min_arity
					messages << Rosace::ErrorMessage.new(
						"Too few arguments for \"#{symbol}\" picker " +
							"(#{min_arity} expected, #{arguments.length} " +
							"given)",
						rule_name,
						entity_id,
						attribute
					)
				elsif arguments.length > max_arity
					messages << Rosace::ErrorMessage.new(
						"Too many arguments for \"#{symbol}\" picker " +
							"(#{max_arity} expected, #{arguments.length} " +
							"given)",
						rule_name,
						entity_id,
						attribute
					)
				end
			else
				messages << Rosace::ErrorMessage.new(
					"No rule named \"#{symbol}\"",
					rule_name,
					entity_id,
					attribute
				)
			end
			arguments.reduce(messages) do |messages, argument|
				messages + argument.verify(context)
			end
		end

		def to_s
			string = symbol.to_s
			unless arguments.empty?
				string += "(#{arguments.map { |arg| arg.to_s }.join(',')})"
			end
			string
		end

		def ==(o)
			super(o) &&
				self.symbol == o.symbol &&
				self.arguments == o.arguments
		end

		def deterministic?
			false
		end

		# Picks an entity from rule {#rule}.
		# @param context [Context] evaluation context
		# @return [Entity] picked entity
		# @raise [EvaluationException] No entities matching given {#arguments}
		def eval(context)
			args = Rosace::ASD.eval_sequence(arguments, context)
			ensure_value(context.pick_entity(symbol, *args))
		end

	end

	# An assignment returning the assigned value.
	class AssignmentExpr < Expression
		
		# @return [Assignment] assignment
		attr_reader :assignment

		# Creates an expression from an assignment.
		# @param [Assignment] assignment assignment
		def initialize(assignment)
			@assignment = assignment
		end

		def set_location(*args)
			super(*args)
			assignment.set_location *args
			nil
		end

		def verify(context)
			super(context) + assignment.verify(context)
		end

		def to_s
			string = assignment.to_s
			"`#{string[1, string.length - 2]}`"
		end

		def ==(o)
			super(o) && self.assignment == o.assignment
		end

		def deterministic?
			assignment.deterministic?
		end

		def eval(context)
			assignment.eval(context)
			ensure_value(context.variable(assignment.symbol))
		end

	end

	# An attribute setter returning the assigned value.
	class SetterExpr < Expression
		
		# @return [AttrSetter] Setter
		attr_reader :setter

		# Creates an expression from a setter.
		# @param setter [AttrSetter] Setter
		def initialize(setter)
			@setter = setter
		end

		def set_location(*args)
			super(*args)
			setter.set_location(*args)
			nil
		end

		def verify(context)
			super(context) + setter.verify(context)
		end

		def to_s
			string = setter.to_s
			"`#{string[1, string.length - 2]}`"
		end

		def ==(o)
			super(o) && self.setter == o.setter
		end

		def deterministic?
			setter.deterministic?
		end

		def eval(context)
			setter.eval(context)
			ensure_value(setter.result)
		end
		
	end

	# A reference to an entity.
	class Reference < Expression
		
		# @return [Symbol] name of the rule
		attr_reader :symbol

		# @return [Integer] id of the entity
		attr_reader :id

		# Creates a reference.
		# @param [Symbol] symbol name of the rule
		# @param [Integer] id id of the entity
		def initialize(symbol, id)
			@symbol = symbol
			@id = id
		end

		def verify(context)
			messages = super(context)
			if context.generator.rules.key?(symbol)
				unless context.entity?(symbol, id)
					messages << Rosace::ErrorMessage.new(
						"No entity of id #{id} in rule \"#{symbol}\"",
						rule_name,
						entity_id,
						attribute
					)
				end
			else
				messages << Rosace::ErrorMessage.new(
					"No rule named \"#{symbol}\"",
					rule_name,
					entity_id,
					attribute
				)
			end
			messages
		end

		def to_s
			"#{symbol}[#{id}]"
		end

		def ==(o)
			super(o) && self.symbol == o.symbol && self.id == o.id
		end

		def deterministic?
			true
		end

		# Returns referenced entity.
		# @param context [Context] evaluation context
		# @return [Entity] referenced entity
		def eval(context)
			ensure_value(context.entity(symbol, id))
		end

	end

	# A symbol, with or without arguments.
	class ChainPart

		# @return [Symbol] Symbol
		attr_reader :symbol

		# @return [Array<Part>] Arguments
		attr_reader :arguments

		# Creates a chain part.
		# @param symbol [Symbol] Symbol
		# @param arguments [Array<Part>] Arguments
		def initialize(symbol, arguments)
			@symbol = symbol
			@arguments = arguments
		end

	end

	# Convert given method +chain+ to expression.
	# @param chain [Array<Expression, nil, ChainPart>] Method chain
	# @return [Expression] inferred expression.
	def chain_to_expression(chain)
		if chain.length == 1
			chain[0] || SymbolReading.new(:self)
		else
			MethodCall.new(
				chain_to_expression(chain[0, chain.length - 1]),
				chain[-1].symbol,
				chain[-1].arguments
			)
		end
	end

	# Creates an AttrSetter from given arguments.
	# @param chain [Array<Expression, ChainPart>] Method chain
	# @param operator ["=", "||="] Assignment operator
	# @param expression [Expression] Value to set
	# @return [AttrSetter] Attribute setter
	# @raise [Rattler::Runtime::SyntaxError] Arguments given to the attribute to
	#  set
	def expr_setter(chain, operator, expression)
		unless chain[-1].arguments.empty?
			raise Rattler::Runtime::SyntaxError,
				"Unexpected argument list \"(#{chain[-1].arguments.map do |arg|
					arg.to_s
				end.join(',')})\""
		end
		AttrSetter.new(
			chain_to_expression(chain[0, chain.length - 1]),
			chain[-1].symbol,
			operator,
			expression
		)
	end

	# Evaluate a sequence of nodes. Retries {MAX_ATTEMPTS} times if an
	#  {EvaluationException} happens and one of the node is non-deterministic.
	# @param nodes [Array<Node>] Sequence of nodes to evaluate
	# @param context [Context] Evaluation context
	# @return [Array] Results of nodes evaluation
	# @raise [EvaluationException] unrescued exception
	def self.eval_sequence(nodes, context)
		parent = context
		attempts = MAX_ATTEMPTS
		deterministic = true
		begin
			context = parent.send(:child)
			deterministic = true
			res = nodes.map do |node|
				out = node.eval(context)
				deterministic &&= node.deterministic?
				out
			end
			context.send(:write_to_parent, local: true)
			res
		rescue Rosace::EvaluationException => e
			if attempts > 0 && !deterministic
				context.log(e)
				attempts -= 1
				retry
			else
				raise e
			end
		end
	end

end
