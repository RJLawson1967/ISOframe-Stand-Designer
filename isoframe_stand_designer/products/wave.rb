# frozen_string_literal: true
# Wave product facade — UI entry points only. Delegates to existing Wave
# modules (Floorspace, Geometry tools, Artwork, …). Do not put Fabric/etc.
# logic here. No mutable product state.

module ISOframe
  module StandDesigner
    module Products
      module Wave
        module_function

        def run_floorspace!
          Floorspace.prompt_and_draw!
        end

        def run_starter!
          Sketchup.active_model.select_tool(Tools::PlaceStarterTool.new)
        end

        def run_extension!
          Sketchup.active_model.select_tool(Tools::PlaceExtensionTool.new)
        end

        def run_flex!
          Sketchup.active_model.select_tool(Tools::FlexTool.new)
        end

        def run_height!
          Tools::HeightSwap.swap_selected!
        end

        def run_artwork!
          Artwork.prompt_and_add!
        end

        def run_light_left!
          Tools::AddLight.toggle_selected!(:left)
        end

        def run_light_right!
          Tools::AddLight.toggle_selected!(:right)
        end

        def run_table_keyboard!
          Tools::AddTable.toggle_selected!('keyboard')
        end

        def run_table_semi_circular!
          Tools::AddTable.toggle_selected!('semi_circular')
        end

        def run_table_square!
          Tools::AddTable.toggle_selected!('square')
        end

        def run_counter_oval!
          Counters.place_selected!('oval')
        end

        def run_screen_small!
          Tools::AddScreen.toggle_selected!('small')
        end

        def run_screen_large!
          Tools::AddScreen.toggle_selected!('large')
        end
      end
    end
  end
end
