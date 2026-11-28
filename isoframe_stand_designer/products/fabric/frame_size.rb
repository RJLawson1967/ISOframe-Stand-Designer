# frozen_string_literal: true
# Fabric Frame Size dialog (v0.1.91) — select Fabric wall → set height + width.
# Starter packs viewer-LEFT; widen grows graphic-front RIGHT.

module ISOframe
  module StandDesigner
    module Products
      module Fabric
        module FrameSize
          module_function

          C = Products::Fabric::Constants

          HEIGHT_CHOICES = [
            ['midi', 'Midi 2270'],
            ['maxi', 'Maxi 2470'],
            ['super_maxi', 'Super-Maxi 3000'],
            ['ultra_maxi', 'Ultra-Maxi 3470']
          ].freeze

          def prompt_selected!
            return false unless License.require_active!
            model = Sketchup.active_model
            walls = fabric_walls_in_selection(model)
            if walls.empty?
              UI.messagebox(
                'Select a Fabric wall (blue frame), then Frame Size.'
              )
              return false
            end
            wall = walls.first
            cur_h = Fabric::Geometry.wall_height_key(wall)
            cur_w = Fabric::Geometry.wall_local_width_mm(wall).to_i
            cur_label = label_for_height(cur_h)
            labels = HEIGHT_CHOICES.map { |_, lab| lab }
            input = UI.inputbox(
              ['Height', 'Width (mm)'],
              [cur_label, cur_w],
              [labels.join('|'), ''],
              walls.size == 1 ? 'Fabric Frame Size' : "Fabric Frame Size (#{walls.size} walls — first used)"
            )
            return false unless input

            height_key = height_key_from_label(input[0])
            unless height_key
              UI.messagebox("Unknown height: #{input[0]}")
              return false
            end
            width = Fabric::Geometry.snap_width_mm(input[1].to_f)
            apply!(wall, height_key, width)
          end

          def apply!(wall, height_key, width_mm)
            return false unless wall && wall.valid?
            height = height_key.to_s
            height = C::DEFAULT_HEIGHT unless C::HEIGHTS_MM.key?(height)
            width = Fabric::Geometry.snap_width_mm(width_mm)
            model = wall.model
            old_width = Fabric::Geometry.wall_local_width_mm(wall)

            model.start_operation('Fabric Frame Size', true)
            begin
              wall.make_unique if wall.respond_to?(:make_unique)
              Fabric::Geometry.rebuild!(wall.definition, width, height)
              # Rename so a resized body is never still called "… w900".
              Fabric::Geometry.ensure_definition_name!(wall.definition, width, height)
              Attributes.set(wall, ::ISOframe::StandDesigner::Constants::KEY_HEIGHT, height)
              Attributes.set(
                wall,
                ::ISOframe::StandDesigner::Constants::KEY_FABRIC_WIDTH_MM,
                width.to_f
              )
              Attributes.set(
                wall,
                ::ISOframe::StandDesigner::Constants::KEY_RANGE,
                ::ISOframe::StandDesigner::Constants::RANGE_FABRIC
              )
              Attributes.set(
                wall,
                ::ISOframe::StandDesigner::Constants::KEY_TYPE,
                ::ISOframe::StandDesigner::Constants::TYPE_FABRIC_WALL
              )
              # Extensions add to the RIGHT (front view); starter stays left-anchored.
              Fabric::Geometry.shift_for_widen_right!(wall, old_width, width)
              Constraints.mark_floor_slide!(wall)
              Constraints.snap_floor_sitting_to_floor!(wall)
              model.selection.clear
              model.selection.add(wall)
              segs = Fabric::Geometry.decompose_width_mm(width)
              Sketchup.status_text =
                "Fabric Frame Size → #{label_for_height(height)} × #{width.to_i} mm " \
                "[#{segs.map(&:to_i).join('+')}] (grows right)"
              model.commit_operation
              true
            rescue StandardError => e
              model.abort_operation
              UI.messagebox("Fabric Frame Size failed:\n#{e.message}")
              false
            end
          end

          def label_for_height(key)
            k = key.to_s
            pair = HEIGHT_CHOICES.find { |hk, _| hk == k }
            return pair[1] if pair
            mm = C::HEIGHTS_MM[k]
            mm ? "#{k} #{mm.to_i}" : C::DEFAULT_HEIGHT
          end

          def height_key_from_label(raw)
            s = raw.to_s.strip
            pair = HEIGHT_CHOICES.find { |_, lab| lab.casecmp(s).zero? }
            return pair[0] if pair
            # Accept bare key or leading token ("Midi", "super_maxi", …).
            down = s.downcase.tr(' ', '_')
            return down if C::HEIGHTS_MM.key?(down)
            token = down.split(/[^a-z_]+/).first.to_s
            map = {
              'midi' => 'midi',
              'maxi' => 'maxi',
              'super' => 'super_maxi',
              'super_maxi' => 'super_maxi',
              'ultra' => 'ultra_maxi',
              'ultra_maxi' => 'ultra_maxi'
            }
            key = map[token]
            return key if key && C::HEIGHTS_MM.key?(key)
            nil
          end

          def fabric_walls_in_selection(model = Sketchup.active_model)
            out = []
            return out unless model
            model.selection.each { |ent| collect_fabric!(ent, out) }
            out.uniq
          end

          def collect_fabric!(ent, out, depth = 0)
            return if ent.nil? || depth > 12
            if ent.is_a?(Sketchup::ComponentInstance)
              out << ent if fabric_wall?(ent)
              ent.definition.entities.each do |child|
                next unless child.is_a?(Sketchup::ComponentInstance) || child.is_a?(Sketchup::Group)
                collect_fabric!(child, out, depth + 1)
              end
            elsif ent.is_a?(Sketchup::Group)
              ent.entities.each do |child|
                next unless child.is_a?(Sketchup::ComponentInstance) || child.is_a?(Sketchup::Group)
                collect_fabric!(child, out, depth + 1)
              end
            end
          end

          def fabric_wall?(ent)
            return false unless ent && ent.valid? && ent.is_a?(Sketchup::ComponentInstance)
            type = Attributes.get(ent, ::ISOframe::StandDesigner::Constants::KEY_TYPE).to_s
            return true if type == ::ISOframe::StandDesigner::Constants::TYPE_FABRIC_WALL
            Attributes.get(ent, ::ISOframe::StandDesigner::Constants::KEY_RANGE).to_s ==
              ::ISOframe::StandDesigner::Constants::RANGE_FABRIC
          end
        end
      end
    end
  end
end
