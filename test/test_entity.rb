require_relative 'test_helper'
require_relative '../lib/rosace/entity'
require_relative '../lib/rosace/context'
require_relative '../lib/rosace/data_types'

class TestEntity < Test::Unit::TestCase

	VALID_DIR1 = 'test/valid_dir1/'
	INVALID_DIR1 = 'test/invalid_dir1/'
	VALID_DIR2 = 'test/valid_dir2/'

	ENUM = [:value1, :value2, :value3]

	def setup
		@valid_dir1 = {
			SimpleRule: Class.new(Rosace::Entity) do
				self.file = VALID_DIR1 + 'simple_rule.csv'

				def value
					"value = #{super}"
				end
			end,

			WeightedRule: Class.new(Rosace::Entity) do
				self.file = VALID_DIR1 + 'weighted_rule.csv'

				def weight
					super * 2
				end
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
		@valid_dir1_st = @valid_dir1_gen.new_evaluation_context
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
			end,
			MalformedMultEnum: Class.new(Rosace::Entity) do
				self.file = INVALID_DIR1 + 'malformed_mult_enum.csv'
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
		@invalid_dir1_st
=end
		@valid_dir2 = {
			MainEntity: Class.new(Rosace::Entity) do
				self.file = VALID_DIR2 + 'main_entity.csv'

				has_many :ReqChild, :parent, :req_child, :required
				has_many :OptChild, :parent, :opt_child, :optional
			end,
			ReqChild: Class.new(Rosace::Entity) do
				self.file = VALID_DIR2 + 'req_child.csv'

				reference :parent, :MainEntity, :required
			end,
			OptChild: Class.new(Rosace::Entity) do
				self.file = VALID_DIR2 + 'opt_child.csv'

				reference :parent, :MainEntity, :required
			end
		}
		@valid_dir2_gen = Rosace::Generator.new(
			path: VALID_DIR2,
			rules: @valid_dir2.values
		)
		@valid_dir2_st = @valid_dir2_gen.new_evaluation_context
	end

	def test_rule_name
		@valid_dir1.each do |name, rule|
			assert_equal(name, rule.rule_name)
		end
		simple_rule = Class.new(Rosace::Entity)
		assert_raise { simple_rule.rule_name }
	end

	def test_lower_snake_case_name
		assert_equal(
			:simple_rule,
			@valid_dir1[:SimpleRule].lower_snake_case_name
		)
		assert_equal(
			:weighted_rule,
			@valid_dir1[:WeightedRule].lower_snake_case_name
		)
		assert_equal(
			:optional_reference,
			@valid_dir1[:OptionalReference].lower_snake_case_name
		)
		assert_equal(
			:required_reference,
			@valid_dir1[:RequiredReference].lower_snake_case_name
		)
		assert_equal(
			:simple_enum,
			@valid_dir1[:SimpleEnum].lower_snake_case_name
		)
		assert_equal(
			:multiple_enum,
			@valid_dir1[:MultipleEnum].lower_snake_case_name
		)
		simple_rule = Class.new(Rosace::Entity)
		assert_raise { simple_rule.lower_snake_case_name }
	end

	def test_file
		assert_equal(
			VALID_DIR1 + 'simple_rule.csv',
			@valid_dir1[:SimpleRule].file
		)
		assert_equal(
			VALID_DIR1 + 'weighted_rule.csv',
			@valid_dir1[:WeightedRule].file
		)
		assert_equal(
			VALID_DIR1 + 'optional_reference.csv',
			@valid_dir1[:OptionalReference].file
		)
		assert_equal(
			VALID_DIR1 + 'required_reference.csv',
			@valid_dir1[:RequiredReference].file
		)
		assert_equal(
			VALID_DIR1 + 'simple_enum.csv',
			@valid_dir1[:SimpleEnum].file
		)
		assert_equal(
			VALID_DIR1 + 'multiple_enum.csv',
			@valid_dir1[:MultipleEnum].file
		)
		simple_rule = Class.new(Rosace::Entity)
		assert_raise { simple_rule.file }
		assert_raise do
			@valid_dir1[:SimpleRule].file = VALID_DIR1 + 'weighted_rule'
		end
		assert_raise do
			Class.new(Rosace::Entity) do
				self.file = VALID_DIR1 + 'super_rule.csv'
			end
		end
		assert_raise do
			Class.new(Rosace::Entity) do
				self.file = INVALID_DIR1 + 'invalid name.csv'
			end
		end
	end

	def test_data_type
		assert_raise do
			@valid_dir1[:SimpleRule].data_type(
				:value,
				Rosace::DataTypes::Text.type
			)
		end
		assert_raise do
			Class.new(Rosace::Entity) do
				self.file = VALID_DIR1 + 'simple_rule.csv'

				data_type :id, Rosace::DataTypes::Reference.new(
					:weighted_rule,
					:required
				)
			end
		end
		assert_raises do
			Class.new(Rosace::Entity) do
				self.file = VALID_DIR1 + 'simple_enum.csv'

				enum :value, *ENUM
				data_type :value, Rosace::DataTypes::Enum[*ENUM]
			end
		end
	end

	def test_attr_types
		assert_equal(
			Rosace::DataTypes::Identifier.type,
			@valid_dir1[:SimpleEnum].attr_types[:id]
		)
		assert_equal(
			Rosace::DataTypes::Weight.type,
			@valid_dir1[:SimpleRule].attr_types[:weight]
		)
		assert_equal(
			Rosace::DataTypes::Text.type,
			@valid_dir1[:SimpleRule].attr_types[:value]
		)
		assert_equal(
			Rosace::DataTypes::Weight.type,
			@valid_dir1[:WeightedRule].attr_types[:weight]
		)
		assert_equal(
			Rosace::DataTypes::Reference.new(:SimpleRule, :optional),
			@valid_dir1[:OptionalReference].attr_types[:entity_ref]
		)
		assert_equal(
			Rosace::DataTypes::Reference.new(:SimpleRule, :required),
			@valid_dir1[:RequiredReference].attr_types[:entity_ref]
		)
		assert_equal(
			Rosace::DataTypes::Enum[*ENUM],
			@valid_dir1[:SimpleEnum].attr_types[:value]
		)
	end

	def test_initialized?
		simple_rule = Class.new(Rosace::Entity) do
			self.file = VALID_DIR1 + 'simple_rule.csv'
		end
		assert_false(simple_rule.initialized?)
		simple_rule.send(:init_rule)
		assert_true(simple_rule.initialized?)
	end

	def test_verify
		assert_empty(
			@valid_dir1[:SimpleRule].send(:verify, @valid_dir1_st)
		)
		assert_empty(
			@valid_dir1[:WeightedRule].send(:verify, @valid_dir1_st)
		)
		assert_empty(
			@valid_dir1[:OptionalReference].send(:verify, @valid_dir1_st)
		)
		assert_empty(
			@valid_dir1[:RequiredReference].send(:verify, @valid_dir1_st)
		)
		assert_empty(
			@valid_dir1[:SimpleEnum].send(:verify, @valid_dir1_st)
		)
		assert_empty(
			@valid_dir1[:MultipleEnum].send(:verify, @valid_dir1_st)
		)
=begin
		assert_not_empty(
			@invalid_dir1[:InvalidId].send(:verify, @invalid_dir1_st)
		)
		assert_not_empty(
			@invalid_dir1[:MissingField].send(:verify, @invalid_dir1_st)
		)
		assert_not_empty(
			@invalid_dir1[:InvalidEnum].send(:verify, @invalid_dir1_st)
		)
		assert_not_empty(
			@invalid_dir1[:NullReference].send(:verify, @invalid_dir1_st)
		)
		assert_not_empty(
			@invalid_dir1[:InvalidReference].send(:verify, @invalid_dir1_st)
		)
=end
	end

	def test_size
		assert_equal(4, @valid_dir1[:SimpleRule].size)
		assert_equal(4, @valid_dir1[:WeightedRule].size)
		assert_equal(4, @valid_dir1[:OptionalReference].size)
		assert_equal(4, @valid_dir1[:RequiredReference].size)
		assert_equal(4, @valid_dir1[:SimpleEnum].size)
		assert_equal(4, @valid_dir1[:MultipleEnum].size)
	end

	def test_entities
		@valid_dir1.each_value do |rule|
			rule.entities.each do |id, entity|
				assert_equal(id, entity.id)
				assert_equal(entity, @valid_dir1[rule.rule_name].entities[id])
				assert_not_same(
					entity,
					@valid_dir1[rule.rule_name].entities[id]
				)
			end
		end
	end

	def test_attr_calls
		assert_equal(3, @valid_dir1_st.entity(:SimpleRule, 3).id)
		assert_equal(40, @valid_dir1_st.entity(:WeightedRule, 2).weight)
		assert_same(:value2, @valid_dir1_st.entity(:SimpleEnum, 4).value)
		assert_same(
			@valid_dir1_st.entity(:SimpleRule, 3),
			@valid_dir1_st.entity(:RequiredReference, 1).entity_ref
		)
		assert_same(
			@valid_dir1_st.entity(:SimpleRule, 1),
			@valid_dir1_st.entity(:OptionalReference, 2).entity_ref
		)
		assert_nil(@valid_dir1_st.entity(
			:OptionalReference,
			3
		).entity_ref)
	end
=begin
	def test_invalid_rules
		assert_raise do
			@invalid_dir1[:NoId].send(:init_rule)
		end
		assert_raise do
			@invalid_dir1[:DuplicatedId].send(:init_rule)
		end
		assert_raise do
			@invalid_dir1[:ExtraField].send(:init_rule)
		end
		assert_raise do
			@invalid_dir1[:Empty].send(:init_rule)
		end
		assert_raise do
			@invalid_dir1[:InvalidAttrName].send(:init_rule)
		end
	end
=end
	def test_entity_call
		assert_raise { Rosace::Entity.rule_name }
		assert_raise { Rosace::Entity.lower_snake_case_name }
		assert_raise { Rosace::Entity.file }
		assert_raise do
			Rosace::Entity.file = VALID_DIR1 + 'simple_rule.csv'
		end
		assert_raise do 
			Rosace::Entity.data_type(
				:value,
				Rosace::DataTypes::Text.type
			)
		end
		assert_raise do
			Rosace::Entity.has_many(:target, :attribute, :optional)
		end
	end

	def test_require_initialized_rule
		assert_raise do
			Rosace::Entity.send(:require_initialized_rule)
		end
		simple_rule = Class.new(Rosace::Entity) do
			self.file = VALID_DIR1 + 'simple_rule.csv'
		end
		assert_raise do
			simple_rule.send(:require_initialized_rule)
		end
	end

	def test_1_N_relations
		assert_equal(
			[
				@valid_dir2_st.entity(:ReqChild, 1),
				@valid_dir2_st.entity(:ReqChild, 3)
			],
			@valid_dir2_st.entity(:MainEntity, 1).req_child_list
		)
		assert_include(
			[
				@valid_dir2_st.entity(:ReqChild, 4),
				@valid_dir2_st.entity(:ReqChild, 5)
			],
			@valid_dir2_st.entity(:MainEntity, 3).req_child
		)
		assert_equal(
			[
				@valid_dir2_st.entity(:OptChild, 2),
				@valid_dir2_st.entity(:OptChild, 3)
			],
			@valid_dir2_st.entity(:MainEntity, 1).opt_child_list
		)
		assert_empty(@valid_dir2_st.entity(:MainEntity, 2).opt_child_list)
		assert_nil(@valid_dir2_st.entity(:MainEntity, 2).opt_child)
		assert_empty(@valid_dir2[:MainEntity].send(:verify, @valid_dir2_st))
	end

	def test_invalid_1_N_relations
		main_entity = Class.new(Rosace::Entity) do
			self.file = VALID_DIR2 + 'main_entity.csv'

			has_many :ReqChild, :parent, :req_child, :required
			has_many :OptChild, :parent, :opt_child, :required
		end
		gen = Rosace::Generator.new(
			path: VALID_DIR2,
			rules: [
				main_entity,
				@valid_dir2[:ReqChild],
				@valid_dir2[:OptChild]
			]
		)
		st = gen.new_evaluation_context
		assert_equal(1, main_entity.send(:verify, st).filter do |message|
			message.level == 'ERROR'
		end.length)
		main_entity = Class.new(Rosace::Entity) do
			self.file = VALID_DIR2 + 'main_entity.csv'

			has_many :ReqChild, :weight, :req_child, :required
			has_many :OptChild, :parent, :opt_child, :optional
		end
		gen = Rosace::Generator.new(
			path: VALID_DIR2,
			rules: [
			main_entity,
			@valid_dir2[:ReqChild],
			@valid_dir2[:OptChild]
		]
		)
		st = gen.new_evaluation_context
		assert_equal(1, main_entity.send(:verify, st).filter do |message|
			message.level == 'ERROR'
		end.length)
		main_entity = Class.new(Rosace::Entity) do
			self.file = VALID_DIR2 + 'main_entity.csv'

			has_many :ReqChild, :parent, :req_child, :required
			has_many :OptChild, :child, :opt_child, :optional
		end
		gen = Rosace::Generator.new(
			path: VALID_DIR2,
			rules: [
			main_entity,
			@valid_dir2[:ReqChild],
			@valid_dir2[:OptChild]
		])
		st = gen.new_evaluation_context
		assert_equal(1, main_entity.send(:verify, st).filter do |message|
			message.level == 'ERROR'
		end.length)
		main_entity = Class.new(Rosace::Entity) do
			self.file = VALID_DIR2 + 'main_entity.csv'

			has_many :ReqChild, :parent, :req_child, :required
			has_many :OtpChild, :parent, :opt_child, :optional
		end
		gen = Rosace::Generator.new(
			path: VALID_DIR2,
			rules: [
			main_entity,
			@valid_dir2[:ReqChild],
			@valid_dir2[:OptChild]
		])
		st = gen.new_evaluation_context
		assert_equal(1, main_entity.send(:verify, st).filter do |message|
			message.level == 'ERROR'
		end.length)
		assert_raise do
			Class.new(Rosace::Entity) do
				self.file = VALID_DIR2 + 'main_entity.csv'

				has_many :ReqChild, :parent, :req_child, :required
				has_many :OptChild, :parent, :req_child, :optional
			end
		end
		assert_raise(ArgumentError) do
			Class.new(Rosace::Entity) do
				self.file = VALID_DIR2 + 'main_entity.csv'

				has_many :ReqChild, :parent, :req_child, :required
				has_many :OptChild, :parent, :opt_child, :relational
			end
		end
		assert_raise do
			@valid_dir2[:MainEntity].has_many(
				:OptChild,
				:parent,
				:opt_child,
				:optional
			)
		end
	end

end