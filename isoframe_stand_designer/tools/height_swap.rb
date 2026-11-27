# frozen_string_literal: true
module ISOframe
  module StandDesigner
    module Tools
      module HeightSwap
        module_function

        def swap_selected!
          model = Sketchup.active_model
          insts = SelectionUtil.wave_modules_in_selection(model)
          if insts.empty?
            UI.messagebox(
              'Select one or more ISOframe Wave modules (or a group that contains them), then Height.'
            )
            return false
          end

          current = Attributes.get(insts.first, Constants::KEY_HEIGHT, Constants::DEFAULT_HEIGHT).to_s
          display = Constants::HEIGHTS_MM.keys.map(&:capitalize)
          input = UI.inputbox(
            ['Height'],
            [current.capitalize],
            [display.join('|')],
            "ISOframe Height (#{insts.size} module#{insts.size == 1 ? '' : 's'})"
          )
          return false unless input
          choice = input[0].to_s.downcase
          unless Constants::HEIGHTS_MM.key?(choice)
            UI.messagebox("Unknown height: #{input[0]}")
            return false
          end
          apply_many!(insts, choice)
        end

        def apply_many!(insts, height_key)
          height_key = height_key.to_s.downcase
          model = Sketchup.active_model
          list = Array(insts).compact.select { |i| i && i.valid? }
          return false if list.empty?

          model.start_operation('ISOframe Height Swap', true)
          begin
            ok = 0
            list.each do |inst|
              ok += 1 if apply_core!(inst, height_key)
            end
            model.commit_operation
            h_mm = Constants::HEIGHTS_MM[height_key].to_i
            Sketchup.status_text =
              "Height → #{height_key.capitalize} (#{h_mm} mm) on #{ok} module#{ok == 1 ? '' : 's'}"
            ok > 0
          rescue StandardError => e
            model.abort_operation
            UI.messagebox("Height swap failed: #{e.message}")
            false
          end
        end

        # Single-module entry (keeps one undo step).
        def apply!(inst, height_key)
          apply_many!([inst], height_key)
        end

        def apply_core!(inst, height_key)
          return false unless inst && inst.valid?
          height_key = height_key.to_s.downcase
          type = Attributes.get(inst, Constants::KEY_TYPE)
          wall_id = Attributes.get(inst, Constants::KEY_WALL)
          flex = Attributes.get(inst, Constants::KEY_FLEX, 0.0).to_f
          range = Attributes.get(inst, Constants::KEY_RANGE, Constants::RANGE_WAVE)
          table = Attributes.get(inst, Constants::KEY_TABLE_TYPE, '').to_s

          defn = Geometry.definition_for(inst.model, type, height_key)
          inst.definition = defn
          Attributes.write_module(
            inst,
            type: type,
            height: height_key,
            wall_id: wall_id,
            flex_angle: flex,
            range: range
          )
          Attributes.set(inst, Constants::KEY_TABLE_TYPE, table) unless table.empty?

          if flex.abs >= 0.5 && table.empty?
            Geometry.apply_flex_to_instance!(inst, flex)
          else
            # Straight (or table-locked straight): unique def + accessories.
            if flex.abs >= 0.5 && !table.empty?
              Attributes.set(inst, Constants::KEY_FLEX, 0.0)
              flex = 0.0
            end
            Lights.sync!(inst) if defined?(Lights)
            Tables.sync!(inst) if defined?(Tables)
            Artwork.reapply_after_rebuild!(inst) if defined?(Artwork)
          end
          Constraints.ensure_module_on_floor!(inst)
          true
        end
      end
    end
  end
end
