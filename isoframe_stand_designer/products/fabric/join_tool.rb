# frozen_string_literal: true
# Fabric Join (v0.1.93) — click near the mating end of each wall (left or right).
# Snap at 90° with 37mm outer-corner join post. Never mirrors/reflects either wall.

module ISOframe
  module StandDesigner
    module Products
      module Fabric
        class JoinTool
          def activate
            @ip = Sketchup::InputPoint.new
            @wall_a = nil
            @end_a = nil
            @wall_b = nil
            @end_b = nil
            @hover_end = nil
            update_status
          end

          def deactivate(view)
            view.invalidate
          end

          def resume(view)
            update_status
            view.invalidate
          end

          def onCancel(_reason, view)
            @wall_a = nil
            @end_a = nil
            @wall_b = nil
            @end_b = nil
            @hover_end = nil
            update_status
            view.invalidate
          end

          def onMouseMove(_flags, x, y, view)
            @ip.pick(view, x, y)
            wall = pick_fabric_wall(view, x, y)
            @hover_wall = wall
            @hover_end = if wall && wall.valid? && @ip.valid?
                           Fabric::Geometry.nearest_end_at_point(wall, @ip.position)
                         end
            update_status
            view.invalidate
          end

          def onLButtonDown(_flags, x, y, view)
            @ip.pick(view, x, y)
            wall = pick_fabric_wall(view, x, y) || selected_fabric_wall
            unless wall && wall.valid?
              UI.messagebox('Fabric Join: click near the left or right end of a Fabric wall.')
              return
            end
            point = @ip.valid? ? @ip.position : wall.transformation.origin
            which = Fabric::Geometry.nearest_end_at_point(wall, point)

            if @wall_a.nil? || !@wall_a.valid?
              @wall_a = wall
              @end_a = which
              update_status
              view.invalidate
              return
            end
            if wall.entityID == @wall_a.entityID
              # Re-pick end on the same wall.
              @end_a = which
              update_status
              view.invalidate
              return
            end
            @wall_b = wall
            @end_b = which
            finish_join!
            view.invalidate
          end

          def draw(view)
            draw_wall_ends(view, @wall_a, @end_a, true) if @wall_a && @wall_a.valid?
            if @hover_wall && @hover_wall.valid? &&
               (@wall_a.nil? || @hover_wall.entityID != @wall_a.entityID)
              draw_wall_ends(view, @hover_wall, @hover_end, false)
            end
            return unless @ip && @ip.valid?
            view.draw_points([@ip.position], 8, 2, 'red')
          end

          def getExtents
            bb = Geom::BoundingBox.new
            bb.add(@ip.position) if @ip && @ip.valid?
            add_wall_tips_to_bb!(bb, @wall_a)
            add_wall_tips_to_bb!(bb, @hover_wall)
            bb
          end

          private

          def draw_wall_ends(view, wall, selected_end, is_anchor)
            left = Fabric::Geometry.viewer_left_tip_world(wall)
            right = Fabric::Geometry.viewer_right_tip_world(wall)
            # Dim both tips; highlight the chosen/hovered mating end.
            view.draw_points([left], 10, 2, selected_end == :left ? 'orange' : 'cyan')
            view.draw_points([right], 10, 2, selected_end == :right ? 'orange' : 'cyan')
            return unless is_anchor && selected_end
            tip = selected_end == :left ? left : right
            view.draw_points([tip], 14, 2, 'orange')
          end

          def add_wall_tips_to_bb!(bb, wall)
            return unless wall && wall.valid?
            bb.add(Fabric::Geometry.viewer_left_tip_world(wall))
            bb.add(Fabric::Geometry.viewer_right_tip_world(wall))
          end

          def update_status
            if @wall_a && @wall_a.valid?
              side = @end_a == :left ? 'LEFT' : 'RIGHT'
              Sketchup.status_text =
                "Fabric Join: wall A #{side} end locked — click near LEFT or RIGHT end of second wall (no mirror). Esc cancels."
            else
              Sketchup.status_text =
                'Fabric Join: click near the LEFT or RIGHT end of the first Fabric wall (anchor; never mirrors).'
            end
          end

          def finish_join!
            model = Sketchup.active_model
            model.start_operation('Fabric Join 90°', true)
            begin
              join = Fabric::Geometry.join_walls_at_right_angle!(
                @wall_a, @wall_b, end_a: @end_a, end_b: @end_b
              )
              unless join
                model.abort_operation
                UI.messagebox('Fabric Join failed.')
                return
              end
              model.selection.clear
              model.selection.add(@wall_a)
              model.selection.add(@wall_b)
              model.selection.add(join)
              a_side = @end_a == :left ? 'left' : 'right'
              b_side = @end_b == :left ? 'left' : 'right'
              Sketchup.status_text =
                "Fabric Join: #{a_side}↔#{b_side} ends at 90° (no mirror; outer-corner post)."
              model.commit_operation
              @wall_a = nil
              @end_a = nil
              @wall_b = nil
              @end_b = nil
              Sketchup.active_model.select_tool(nil)
            rescue StandardError => e
              model.abort_operation
              UI.messagebox("Fabric Join failed:\n#{e.message}")
            end
          end

          def selected_fabric_wall
            model = Sketchup.active_model
            return nil unless model
            model.selection.grep(Sketchup::ComponentInstance).find { |e| fabric_wall?(e) }
          end

          def fabric_wall?(ent)
            return false unless ent && ent.valid? && ent.is_a?(Sketchup::ComponentInstance)
            Attributes.get(ent, ::ISOframe::StandDesigner::Constants::KEY_TYPE).to_s ==
              ::ISOframe::StandDesigner::Constants::TYPE_FABRIC_WALL
          end

          def pick_fabric_wall(view, x, y)
            ph = view.pick_helper
            ph.do_pick(x, y)
            best = nil
            ph.count.times do |i|
              path = ph.path_at(i)
              next unless path
              path.reverse_each do |e|
                if fabric_wall?(e)
                  best = e
                  break
                end
              end
              break if best
            end
            best
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
