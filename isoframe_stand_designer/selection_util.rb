# frozen_string_literal: true
# Collect ISOframe Wave modules from the current selection, including modules
# nested inside selected SketchUp groups / components.

module ISOframe
  module StandDesigner
    module SelectionUtil
      module_function

      def wave_modules_in_selection(model = Sketchup.active_model)
        out = []
        return out unless model
        model.selection.each { |ent| collect_wave_modules!(ent, out) }
        out.uniq
      end

      def collect_wave_modules!(ent, out, depth = 0)
        return if ent.nil? || depth > 12

        if ent.is_a?(Sketchup::ComponentInstance)
          out << ent if wave_module?(ent)
          ent.definition.entities.each do |child|
            next unless child.is_a?(Sketchup::ComponentInstance) || child.is_a?(Sketchup::Group)
            collect_wave_modules!(child, out, depth + 1)
          end
        elsif ent.is_a?(Sketchup::Group)
          ent.entities.each do |child|
            next unless child.is_a?(Sketchup::ComponentInstance) || child.is_a?(Sketchup::Group)
            collect_wave_modules!(child, out, depth + 1)
          end
        end
      end

      def wave_module?(inst)
        return false unless inst && inst.valid?
        type = Attributes.get(inst, Constants::KEY_TYPE)
        return false unless type == Constants::TYPE_STARTER || type == Constants::TYPE_EXTENSION
        Attributes.get(inst, Constants::KEY_RANGE) == Constants::RANGE_WAVE
      end
    end
  end
end
