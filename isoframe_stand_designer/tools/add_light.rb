# frozen_string_literal: true
module ISOframe
  module StandDesigner
    module Tools
      module AddLight
        module_function

        def toggle_selected!(side)
          model = Sketchup.active_model
          inst = selected_module(model)
          unless inst
            UI.messagebox('Select a Wave starter or extension first, then Add Light Left/Right.')
            return false
          end

          side_label = side.to_s.downcase == 'left' ? 'Left' : 'Right'
          model.start_operation("ISOframe Add Light #{side_label}", true)
          begin
            now_on = Lights.toggle!(inst, side)
            model.commit_operation
            state = now_on ? 'on' : 'off'
            Sketchup.status_text = "Flood light #{side_label} → #{state}"
            true
          rescue StandardError => e
            model.abort_operation
            UI.messagebox("Add Light failed: #{e.message}")
            false
          end
        end

        def selected_module(model)
          model.selection.grep(Sketchup::ComponentInstance).find do |i|
            Attributes.module_attrs?(i)
          end
        end
      end
    end
  end
end
