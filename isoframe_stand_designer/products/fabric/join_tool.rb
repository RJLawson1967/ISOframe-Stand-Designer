# frozen_string_literal: true
# Fabric Join (v0.1.89) — click two walls; snap at 90° with optional 37mm join post.
# Join post height = lowest of the two walls. Sold as option; click into place.

module ISOframe
  module StandDesigner
    module Products
      module Fabric
        class JoinTool
          def activate
            @ip = Sketchup::InputPoint.new
            @wall_a = selected_fabric_wall
            @wall_b = nil
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
            @wall_b = nil
            update_status
            view.invalidate
          end

          def onMouseMove(_flags, x, y, view)
            @ip.pick(view, x, y)
            view.invalidate
          end

          def onLButtonDown(_flags, x, y, view)
            @ip.pick(view, x, y)
            wall = pick_fabric_wall(view, x, y) || selected_fabric_wall
            unless wall && wall.valid?
              UI.messagebox('Fabric Join: click a Fabric wall.')
              return
            end
            if @wall_a.nil? || !@wall_a.valid?
              @wall_a = wall
              update_status
              view.invalidate
              return
            end
            if wall.entityID == @wall_a.entityID
              UI.messagebox('Fabric Join: click a second, different Fabric wall.')
              return
            end
            @wall_b = wall
            finish_join!
            view.invalidate
          end

          def draw(view)
            if @wall_a && @wall_a.valid?
              tip = Fabric::Geometry.viewer_right_tip_world(@wall_a)
              view.draw_points([tip], 12, 2, 'orange')
            end
            return unless @ip && @ip.valid?
            view.draw_points([@ip.position], 8, 2, 'red')
          end

          def getExtents
            bb = Geom::BoundingBox.new
            bb.add(@ip.position) if @ip && @ip.valid?
            if @wall_a && @wall_a.valid?
              bb.add(Fabric::Geometry.viewer_right_tip_world(@wall_a))
            end
            bb
          end

          private

          def update_status
            if @wall_a && @wall_a.valid?
              Sketchup.status_text =
                'Fabric Join: click the second wall to snap at 90° (37 mm join post). Esc cancels.'
            else
              Sketchup.status_text =
                'Fabric Join: click the first Fabric wall (anchor). Second wall snaps at 90° on its right.'
            end
          end

          def finish_join!
            model = Sketchup.active_model
            model.start_operation('Fabric Join 90°', true)
            begin
              join = Fabric::Geometry.join_walls_at_right_angle!(@wall_a, @wall_b)
              unless join
                model.abort_operation
                UI.messagebox('Fabric Join failed.')
                return
              end
              model.selection.clear
              model.selection.add(@wall_a)
              model.selection.add(@wall_b)
              model.selection.add(join)
              Sketchup.status_text =
                'Fabric Join: walls snapped at 90° with 37 mm join post (height = shortest wall).'
              model.commit_operation
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
