# frozen_string_literal: true
# Extensions → ISOframe Stand Designer.
# v0.1.81: Panel / License / About at top level; Wave tools under Wave submenu.
# Other product lines get empty “coming soon” submenus (firewall shells).
# v0.1.82: Fabric submenu — Place Midi + Edge Snap (no flex).
# v0.1.84: Frame Size replaces Edge Snap.

module ISOframe
  module StandDesigner
    module AppMenu
      module_function

      def install!
        return if @installed
        menu = UI.menu('Extensions').add_submenu('ISOframe Stand Designer')

        menu.add_item('Panel…') { Dialog.show! }
        menu.add_item('License…') { License.prompt_and_set! }
        menu.add_item('About') do
          UI.messagebox(
            "#{EXTENSION_NAME} v#{EXTENSION_VERSION}\n" \
            "Wave · Fabric · Lumen · Ripple · ISObar · Express\n" \
            'ISOframe / Richard Lawson'
          )
        end
        menu.add_separator
        menu.add_item('New Job / Floorspace…') { Floorspace.prompt_and_draw! }
        menu.add_separator

        install_wave_submenu!(menu)
        install_fabric_submenu!(menu)
        install_shell_submenu!(menu, 'lumen', Products::Lumen)
        install_shell_submenu!(menu, 'ripple', Products::Ripple)
        install_shell_submenu!(menu, 'isobar', Products::ISObar)
        install_shell_submenu!(menu, 'express', Products::Express)

        @installed = true
      end

      def install_wave_submenu!(menu)
        wave = menu.add_submenu(Products.label_for('wave'))
        wave.add_item('Place Starter') { Products::Wave.run_starter! }
        wave.add_item('Place Extension') { Products::Wave.run_extension! }
        wave.add_item('Flex…') { Products::Wave.run_flex! }
        wave.add_item('Height…') { Products::Wave.run_height! }
        wave.add_item('Add Artwork…') { Products::Wave.run_artwork! }
        wave.add_item('Add Light Left') { Products::Wave.run_light_left! }
        wave.add_item('Add Light Right') { Products::Wave.run_light_right! }
        wave.add_separator
        wave.add_item('Keyboard Table') { Products::Wave.run_table_keyboard! }
        wave.add_item('Semi-circular table attachment') { Products::Wave.run_table_semi_circular! }
        wave.add_item('Square Table attachment') { Products::Wave.run_table_square! }
        wave.add_item('Oval Counter') { Products::Wave.run_counter_oval! }
        wave.add_item('Media Screen Small') { Products::Wave.run_screen_small! }
        wave.add_item('Media Screen Large') { Products::Wave.run_screen_large! }
      end

      def install_fabric_submenu!(menu)
        fabric = menu.add_submenu(Products.label_for('fabric'))
        fabric.add_item('Place Fabric Midi (900×2270)') { Products::Fabric.run_place_midi! }
        fabric.add_item('Frame Size…') { Products::Fabric.run_frame_size! }
      end

      def install_shell_submenu!(menu, id, mod)
        sub = menu.add_submenu(Products.label_for(id))
        sub.add_item(mod.coming_soon_message) do
          UI.messagebox(mod.coming_soon_message)
        end
      end
    end
  end
end
