# frozen_string_literal: true
module ISOframe
  module StandDesigner
    module WallMath
      module_function

      def overall_width_mm(graphic_count)
        n = graphic_count.to_i
        return 0 if n <= 0
        n * Constants::GRAPHIC_BAY_MM + Constants::POST_MM
      end

      def format_width(graphic_count)
        mm = overall_width_mm(graphic_count)
        "#{graphic_count} × #{Constants::GRAPHIC_BAY_MM.to_i} + #{Constants::POST_MM.to_i} = #{mm.to_i} mm"
      end

      def graphic_count_for_wall(model, wall_id)
        return 0 if wall_id.nil? || wall_id.to_s.empty?
        count = 0
        model.active_entities.grep(Sketchup::ComponentInstance).each do |inst|
          next unless Attributes.get(inst, Constants::KEY_WALL).to_s == wall_id.to_s
          next unless Attributes.get(inst, Constants::KEY_RANGE) == Constants::RANGE_WAVE
          count += 1
        end
        count
      end

      def status_line_for_wall(model, wall_id)
        n = graphic_count_for_wall(model, wall_id)
        return 'No modules on this wall' if n.zero?
        "Straight wall (#{n} graphics): #{overall_width_mm(n).to_i} mm — #{format_width(n)}"
      end
    end
  end
end
