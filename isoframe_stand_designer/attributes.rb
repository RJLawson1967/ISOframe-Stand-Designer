# frozen_string_literal: true
module ISOframe
  module StandDesigner
    module Attributes
      module_function

      def dict_name
        Constants::DICT
      end

      def get(entity, key, default = nil)
        return default unless entity
        dict = entity.attribute_dictionary(dict_name)
        return default unless dict
        val = dict[key]
        val.nil? ? default : val
      end

      def set(entity, key, value)
        return unless entity
        entity.set_attribute(dict_name, key, value)
      end

      def set_many(entity, hash)
        hash.each { |k, v| set(entity, k, v) }
      end

      def module_attrs?(entity)
        get(entity, Constants::KEY_TYPE)
      end

      def write_module(entity, type:, height:, wall_id:, flex_angle: 0.0, range: Constants::RANGE_WAVE)
        set_many(entity, {
          Constants::KEY_RANGE => range,
          Constants::KEY_TYPE => type.to_s,
          Constants::KEY_HEIGHT => height.to_s,
          Constants::KEY_FLEX => flex_angle.to_f,
          Constants::KEY_WALL => wall_id.to_s
        })
      end
    end
  end
end
