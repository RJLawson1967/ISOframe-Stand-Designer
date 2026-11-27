# frozen_string_literal: true
module ISOframe
  module StandDesigner
    module AppMenu
      module_function

      def install!
        return if @installed
        menu = UI.menu('Extensions').add_submenu('ISOframe Stand Designer')
        menu.add_item('New Job…') { Floorspace.prompt_and_draw! }
        menu.add_item('Floorspace…') { Floorspace.prompt_and_draw! }
        menu.add_separator
        menu.add_item('Place Starter') do
          Sketchup.active_model.select_tool(Tools::PlaceStarterTool.new)
        end
        menu.add_item('Place Extension') do
          Sketchup.active_model.select_tool(Tools::PlaceExtensionTool.new)
        end
        menu.add_item('Flex…') do
          Sketchup.active_model.select_tool(Tools::FlexTool.new)
        end
        menu.add_item('Height…') { Tools::HeightSwap.swap_selected! }
        menu.add_item('Add Artwork…') { Artwork.prompt_and_add! }
        menu.add_item('Add Light Left') { Tools::AddLight.toggle_selected!(:left) }
        menu.add_item('Add Light Right') { Tools::AddLight.toggle_selected!(:right) }
        menu.add_separator
        menu.add_item('Keyboard Table') { Tools::AddTable.toggle_selected!('keyboard') }
        menu.add_item('Semi-circular table attachment') { Tools::AddTable.toggle_selected!('semi_circular') }
        menu.add_item('Square Table attachment') { Tools::AddTable.toggle_selected!('square') }
        menu.add_item('Oval Counter') { Counters.place_selected!('oval') }
        menu.add_separator
        menu.add_item('Panel…') { Dialog.show! }
        menu.add_item('License…') { License.prompt_and_set! }
        menu.add_item('About') do
          UI.messagebox(
            "#{EXTENSION_NAME} v#{EXTENSION_VERSION}\n" \
            "Wave flexible MVP scaffold\n" \
            'ISOframe / Richard Lawson'
          )
        end
        @installed = true
      end
    end
  end
end
