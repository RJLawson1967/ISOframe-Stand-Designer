# frozen_string_literal: true
# Fabric product (v0.1.90) — place Midi, Frame Size (grows right), Join 90°.
# Fabric covers entire Al frame; all geometry above floorspace top.
# Firewall: no Wave flex / Geometry rebuild. Floorspace is shared UI only.

module ISOframe
  module StandDesigner
    module Products
      module Fabric
        module_function

        PRODUCT_ID = 'fabric'

        def ready?
          true
        end

        def coming_soon_message
          Products.coming_soon_message(PRODUCT_ID)
        end

        def run_floorspace!
          Floorspace.prompt_and_draw!
        end

        def run_place_midi!
          return unless License.require_active!
          Sketchup.active_model.select_tool(PlaceTool.new)
          true
        end

        def run_frame_size!
          FrameSize.prompt_selected!
        end

        def run_join!
          return unless License.require_active!
          walls = FrameSize.fabric_walls_in_selection
          if walls.size >= 2
            model = Sketchup.active_model
            model.start_operation('Fabric Join 90°', true)
            begin
              join = Geometry.join_walls_at_right_angle!(walls[0], walls[1])
              raise 'Join failed' unless join
              model.selection.clear
              model.selection.add(walls[0])
              model.selection.add(walls[1])
              model.selection.add(join)
              Sketchup.status_text =
                'Fabric Join: walls snapped at 90° with 37 mm join post.'
              model.commit_operation
            rescue StandardError => e
              model.abort_operation
              UI.messagebox("Fabric Join failed:\n#{e.message}")
            end
            return true
          end
          Sketchup.active_model.select_tool(JoinTool.new)
          true
        end
      end
    end
  end
end
