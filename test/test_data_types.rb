require_relative 'test_helper'
require_relative '../lib/rosace/function'
require_relative '../lib/rosace/entity'
require_relative '../lib/rosace/context'
require_relative '../lib/rosace/data_types'

class TestDataTypes < Test::Unit::TestCase

	VALID_DIR1 = 'test/valid_dir1/'
	INVALID_DIR1 = 'test/invalid_dir1/'

	ENUM = [:value1, :value2, :value3]

	def setup
		@enum = Rosace::DataTypes::Enum[*ENUM]
		@identifier = Rosace::DataTypes::Identifier.type
		@opt_ref = Rosace::DataTypes::Reference.new(:target, :optional)
		@req_ref = Rosace::DataTypes::Reference.new(:target, :required)
		@text = Rosace::DataTypes::Text.type
		@weight = Rosace::DataTypes::Weight.type
		@mult_enum = Rosace::DataTypes::MultEnum[*ENUM]

		@simple_rule_opt_ref = Rosace::DataTypes::Reference.new(
			:SimpleRule,
			:optional
		)
		@simple_rule_req_ref = Rosace::DataTypes::Reference.new(
			:SimpleRule,
			:required
		)

		@valid_dir1 = {
			SimpleRule: Class.new(Rosace::Entity) do
				self.file = VALID_DIR1 + 'simple_rule.csv'
			end,

			WeightedRule: Class.new(Rosace::Entity) do
				self.file = VALID_DIR1 + 'weighted_rule.csv'
			end,

			OptionalReference: Class.new(Rosace::Entity) do
				self.file = VALID_DIR1 + 'optional_reference.csv'

				reference :entity_ref, :SimpleRule, :optional
			end,

			RequiredReference: Class.new(Rosace::Entity) do
				self.file = VALID_DIR1 + 'required_reference.csv'

				reference :entity_ref, :SimpleRule, :required
			end,

			SimpleEnum: Class.new(Rosace::Entity) do
				self.file = VALID_DIR1 + 'simple_enum.csv'

				enum :value, *ENUM
			end,

			MultipleEnum: Class.new(Rosace::Entity) do
				self.file = VALID_DIR1 + 'multiple_enum.csv'

				mult_enum :values, *ENUM
			end
		}
		@valid_dir1_gen = Rosace::Generator.new(
			path: VALID_DIR1,
			rules: @valid_dir1.values
		)
		@valid_dir1_st = Rosace::Context.new(@valid_dir1_gen)
=begin
		@invalid_dir1 = {
			SimpleRule: Class.new(Rosace::Entity) do
				self.file = INVALID_DIR1 + 'simple_rule.csv'
			end,
			NoId: Class.new(Rosace::Entity) do
				self.file = INVALID_DIR1 + 'no_id.csv'
			end,
			InvalidId: Class.new(Rosace::Entity) do
				self.file = INVALID_DIR1 + 'invalid_id.csv'
			end,
			DuplicatedId: Class.new(Rosace::Entity) do
				self.file = INVALID_DIR1 + 'duplicated_id.csv'
			end,
			ExtraField: Class.new(Rosace::Entity) do
				self.file = INVALID_DIR1 + 'extra_field.csv'
			end,
			MissingField: Class.new(Rosace::Entity) do
				self.file = INVALID_DIR1 + 'missing_field.csv'
			end,
			Empty: Class.new(Rosace::Entity) do
				self.file = INVALID_DIR1 + 'empty.csv'
			end,
			InvalidEnum: Class.new(Rosace::Entity) do
				self.file = INVALID_DIR1 + 'invalid_enum.csv'

				enum :value, *ENUM
			end,
			InvalidMultEnum: Class.new(Rosace::Entity) do
				self.file = INVALID_DIR1 + 'invalid_mult_enum.csv'

				mult_enum :values, *ENUM
			end,
			MalformedMultEnum: Class.new(Rosace::Entity) do
				self.file = INVALID_DIR1 + 'malformed_mult_enum.csv'

				mult_enum :values, *ENUM
			end,
			NullReference: Class.new(Rosace::Entity) do
				self.file = INVALID_DIR1 + 'null_reference.csv'

				reference :ref, :SimpleRule, :required
			end,
			InvalidReference: Class.new(Rosace::Entity) do
				self.file = INVALID_DIR1 + 'invalid_reference.csv'

				reference :ref, :SimpleRule, :required
			end,
			InvalidAttrName: Class.new(Rosace::Entity) do
				self.file = INVALID_DIR1 + 'invalid_attr_name.csv'
			end
		}
		@invalid_dir1_gen = Rosace::Generator.new(
			path: INVALID_DIR1,
			rules: [
			@invalid_dir1[:SimpleRule],
			@invalid_dir1[:InvalidId],
			@invalid_dir1[:MissingField],
			@invalid_dir1[:InvalidEnum],
			@invalid_dir1[:InvalidMultEnum],
			@invalid_dir1[:MalformedMultEnum],
			@invalid_dir1[:NullReference],
			@invalid_dir1[:InvalidReference]
		])
		@invalid_dir1_st = @invalid_dir1_gen.new_evaluation_context
=end
		@floc = [:SimpleRule, 1, :value]
	end

	def test_inspect
		assert_equal('Enum<:value1, :value2, :value3>', @enum.inspect)
		assert_equal('MultEnum<:value1, :value2, :value3>', @mult_enum.inspect)
		assert_equal('Identifier', @identifier.inspect)
		assert_equal('Reference<target, optional>', @opt_ref.inspect)
		assert_equal('Text', @text.inspect)
		assert_equal('Weight', @weight.inspect)
	end

	def test_inspect_value
		assert_equal(':value2', @enum.data(*@floc, ' value2	').inspect)
		assert_equal(
			'[:value1, :value3]',
			@mult_enum.data(*@floc, 'value1 value3').inspect
		)
		assert_equal('8', @identifier.data(*@floc, ' 8').inspect)
		assert_equal('target[2]', @req_ref.data(*@floc, '2
			').inspect)
		assert_equal('target[0]', @opt_ref.data(*@floc, '').inspect)
		assert_equal(
			'" my string"',
			@text.data(*@floc, ' my string').inspect
		)
		assert_equal('10', @weight.data(*@floc, '10').inspect)
	end

	def test_verify
		assert_empty(@identifier.data(*@floc, '2').verify(@valid_dir1_st))
=begin
		assert_equal(1, @identifier.data(*@floc, '-3').verify(@invalid_dir1_st).
			filter { |message| message.level == 'ERROR' }.length)
		assert_equal(
			1,
			@identifier.data(*@floc, 'b').verify(@invalid_dir1_st).
				filter do |message|
				message.level == 'WARNING'
			end.length
		)
=end
		assert_empty(@weight.data(*@floc, '0').verify(@valid_dir1_st))
=begin
		assert_equal(
			1,
			@weight.data(*@floc, '-3').verify(@invalid_dir1_st).
				filter do |message|
				message.level == 'ERROR'
			end.length
		)
		assert_empty(@enum.data(*@floc, '  value2').verify(@valid_dir1_st))
		assert_equal(1, @enum.data(*@floc, 'value4').verify(@invalid_dir1_st).
			filter { |message| message.level == 'ERROR' }.length)
		assert_empty(@simple_rule_opt_ref.data(*@floc, ' ').
			verify(@valid_dir1_st))
		assert_equal(1, @simple_rule_req_ref.data(*@floc, '').
			verify(@valid_dir1_st).filter do |message|
				message.level == 'ERROR' 
			end.length)
		assert_empty(@simple_rule_req_ref.data(*@floc, '2').
			verify(@valid_dir1_st))
		assert_equal(1, @simple_rule_req_ref.data(*@floc, '8').
			verify(@invalid_dir1_st).filter do |message|
				message.level == 'ERROR' 
		end.length)
		assert_equal(1, @simple_rule_opt_ref.data(*@floc, '8').
			verify(@invalid_dir1_st).filter do |message|
				message.level == 'WARNING' 
			end.length)
		assert_equal(
			1,
			@text.data(*@floc, nil).verify(@valid_dir1_st).filter do |message|
				message.level == 'ERROR'
			end.length
		)
		assert_empty(@mult_enum.data(*@floc, "value2 \tvalue1").
			verify(@valid_dir1_st))
		assert_equal(1, @mult_enum.data(*@floc, "value4 value1").
			verify(@invalid_dir1_st).filter do |message|
				message.level == 'ERROR'
			end.length)
		assert_equal(1, @mult_enum.data(*@floc, "value3;value2").
			verify(@invalid_dir1_st).filter do |message|
				message.level == 'ERROR'
			end.length)
		assert_equal(
			1,
			@text.data(*@floc, "{var").verify(@valid_dir1_st).filter do |m|
				m.level == "ERROR"
			end.length
		)
=end
	end

	def test_verify_self
		assert_empty(@text.verify(@valid_dir1_st))
		assert_empty(@simple_rule_opt_ref.verify(
			@valid_dir1_st,
			@valid_dir1[:OptionalReference],
			:entity_ref
		))
		assert_equal(1, @opt_ref.verify(@valid_dir1_st).filter do |message|
			message.level == 'ERROR'
		end.length)
	end

	def test_convert
		assert_equal(
			'simple entity 3',
			@text.data(*@floc, 'simple entity 3').value(@valid_dir1_st)
		)
		assert_equal(
			2,
			@identifier.data(*@floc, "2\t").value(@valid_dir1_st)
		)
		assert_equal(
			5,
			@weight.data(*@floc, '5').value(@valid_dir1_st)
		)
		assert_equal(
			:value1,
			@enum.data(*@floc, ' value1 ').value(@valid_dir1_st)
		)
		assert_equal(
			[:value2, :value1],
			@mult_enum.data(*@floc, "value2 \tvalue1").value(@valid_dir1_st)
		)
		assert_equal(
			[],
			@mult_enum.data(*@floc, " ").value(@valid_dir1_st)
		)
		assert_equal(
			@valid_dir1_st.entity(:SimpleRule, 3),
			@simple_rule_req_ref.data(*@floc, '3').value(@valid_dir1_st)
		)
		assert_nil(@simple_rule_opt_ref.data(*@floc, ' ').value(@valid_dir1_st))
		assert_equal(
			"simple entity 3",
			@text.data(*@floc, "{SimpleRule[3]}").value(@valid_dir1_st)
		)
	end

	def test_equal
		assert_equal(
			Rosace::DataTypes::Enum[:value1, :value3, :value2],
			Rosace::DataTypes::Enum[:value3, :value1, :value2]
		)
		assert_equal(
			Rosace::DataTypes::MultEnum[:value1, :value3, :value2],
			Rosace::DataTypes::MultEnum[:value3, :value1, :value2]
		)
		assert_equal(
			@opt_ref,
			Rosace::DataTypes::Reference.new(:target, :optional)
		)
	end

	def test_initialization
		assert_raise(ArgumentError) do
			Rosace::DataTypes::Reference.new(:target, :optimal)
		end
	end

	def test_multiple_calls
		my_text = Rosace::DataTypes::Text.type.data(
			*@floc,
			"{$my_var = s(arg1|arg2)}"
		)
		assert_empty(my_text.value(@valid_dir1_st))
		val = @valid_dir1_st.variable(:$my_var)
		assert_include(["arg1", "arg2"], val)
		assert_empty(my_text.value(@valid_dir1_st))
		assert_equal(val, @valid_dir1_st.variable(:$my_var))
	end

	def test_single_call_fail
		my_text = Rosace::DataTypes::Text.type.data(
			*@floc,
			"{my_var = s(arg1|arg2)}"
		)
		@valid_dir1_st.store_variable!(:my_var, "my string")
		assert_raise(Rosace::EvaluationException) do
			my_text.value(@valid_dir1_st)
		end
	end

end