module Steep
  module TypeInference
    class BlockParams
      class Param
        attr_reader :var
        attr_reader :type
        attr_reader :value
        attr_reader :node

        def initialize(var:, type:, value:, node:)
          @var = var
          @type = type
          @value = value
          @node = node
        end

        def ==(other)
          other.is_a?(Param) && other.var == var && other.type == type && other.value == value && other.node == node
        end

        alias eql? ==

        def hash
          self.class.hash ^ var.hash ^ type.hash ^ value.hash ^ node.hash
        end
      end

      attr_reader :params
      attr_reader :rest

      def initialize(params:, rest:)
        @params = params
        @rest = rest
      end

      def self.from_node(node, annotations:)
        params = []
        rest = nil

        node.children.each do |arg|
          var = arg.children.first
          type = annotations.lookup_var_type(var.name)

          case arg.type
          when :arg, :procarg0
            params << Param.new(var: var, type: type, value: nil, node: arg)
          when :optarg
            params << Param.new(var: var, type: type, value: arg.children.last, node: arg)
          when :restarg
            rest = Param.new(var: var, type: type, value: nil, node: arg)
          end
        end

        new(
          params: params,
          rest: rest
        )
      end

      def zip(params_type)
        [].tap do |zip|
          types = params_type.flat_unnamed_params
          params.each do |param|
            type = types.shift&.last || params_type.rest || AST::Types::Any.new

            if type
              zip << [param, type]
            end
          end

          if rest
            if types.empty?
              array = AST::Types::Name.new_instance(
                name: :Array,
                args: [params_type.rest || AST::Types::Any.new]
              )
              zip << [rest, array]
            else
              union = AST::Types::Union.build(types: types.map(&:last) + [params_type.rest])
              array = AST::Types::Name.new_instance(
                name: :Array,
                args: [union]
              )
              zip << [rest, array]
            end
          end
        end
      end

      def each(&block)
        if block_given?
          params.each &block
          yield rest if rest
        else
          enum_for :each
        end
      end
    end
  end
end
