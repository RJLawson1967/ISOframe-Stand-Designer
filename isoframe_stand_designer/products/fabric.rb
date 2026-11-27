# frozen_string_literal: true
# Fabric product (v0.1.82) — place Midi starter + edge-snap height/width.
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

        def run_edge_snap!
          return unless License.require_active!
          Sketchup.active_model.select_tool(EdgeSnapTool.new)
          true
        end
      end
    end
  end
end
