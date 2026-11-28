# frozen_string_literal: true
# Procedural Fabric wall (v0.1.91) — 37mm Al frame + 12.5mm round braces, fabric cover.
# Starter packs viewer-LEFT; Join post at OUTER corner (plan), purple graphics inside.

module ISOframe
  module StandDesigner
    module Products
      module Fabric
        module Geometry
          module_function

          C = Products::Fabric::Constants

          def height_mm(height_key)
            C::HEIGHTS_MM[height_key.to_s] || C::HEIGHTS_MM[C::DEFAULT_HEIGHT]
          end

          # Post tip slightly below fabric top so fabric covers the Al tip.
          def post_tip_mm(height_key)
            g = height_mm(height_key)
            g - C::GRAPHIC_TOP_ABOVE_POST_MM
          end

          # Width = 900 + k×250. Never snap the 900 starter via (w/250).round
          # (that turns 900 into 1000 because 900/250 = 3.6 → 4).
          def snap_width_mm(raw_mm)
            w = raw_mm.to_f
            base = C::STARTER_WIDTH_MM
            step = C::WIDTH_STEP_MM
            w = base if w < base
            rem = w - base
            steps = (rem / step).round
            steps = 0 if steps < 0
            snapped = base + (steps * step)
            snapped = 50_000.0 if snapped > 50_000.0
            snapped.to_f
          end

          def snap_height_key(raw_mm)
            h = raw_mm.to_f
            best = C::DEFAULT_HEIGHT
            best_d = 1.0e12
            C::HEIGHT_SNAP_ORDER.each do |key|
              d = (C::HEIGHTS_MM[key] - h).abs
              if d < best_d
                best_d = d
                best = key
              end
            end
            best
          end

          # 900 + greedy pack of 1000/750/500/250 covering (width − 900).
          def decompose_width_mm(total_mm)
            total = snap_width_mm(total_mm)
            rem = (total - C::STARTER_WIDTH_MM).round
            segs = [C::STARTER_WIDTH_MM]
            C::EXTENSION_WIDTHS_MM.each do |piece|
              piece_i = piece.round
              while rem >= piece_i
                segs << piece
                rem -= piece_i
              end
            end
            segs
          end

          def placement_transform(origin)
            # Same RH ψ=180° as Wave: graphic +Y → world −Y (faces floorspace).
            # Local +X → world −X = viewer LEFT; local 0 tip = viewer RIGHT.
            # Frame Size widen shifts origin so growth appears on viewer RIGHT.
            Geom::Transformation.new(
              Geom::Vector3d.new(-1, 0, 0),
              Geom::Vector3d.new(0, -1, 0),
              Geom::Vector3d.new(0, 0, 1),
              origin
            )
          end

          # World point of local (x_mm, 0, 0) on the wall instance (plan Z ignored).
          def world_point_on_wall(wall, x_mm)
            tr = wall.transformation
            local = Geom::Point3d.new(x_mm.to_f.mm, 0, 0)
            local.transform(tr)
          end

          # Viewer-RIGHT tip (local x=0 outer) under ψ=180° Place.
          def viewer_right_tip_world(wall)
            world_point_on_wall(wall, 0.0)
          end

          # Viewer-LEFT tip (local x=width outer) under ψ=180° Place.
          def viewer_left_tip_world(wall)
            w = wall_local_width_mm(wall)
            world_point_on_wall(wall, w)
          end

          # After rebuild to a new width: keep viewer-LEFT (starter side) fixed in
          # world; shift instance so added length appears on viewer-RIGHT.
          def shift_for_widen_right!(wall, old_width_mm, new_width_mm)
            return unless wall && wall.valid?
            delta = new_width_mm.to_f - old_width_mm.to_f
            return if delta.abs < 0.5
            xaxis = wall.transformation.xaxis
            # Translate opposite local +X by delta → origin (viewer-right tip) moves
            # viewer-right; viewer-left tip stays put.
            shift = Geom::Vector3d.new(
              -xaxis.x * delta.mm,
              -xaxis.y * delta.mm,
              0.0
            )
            wall.transform!(Geom::Transformation.translation(shift))
            Constraints.snap_floor_sitting_to_floor!(wall)
          end

          def join_post_definition!(model, tip_mm)
            tip = tip_mm.to_f
            tip = 100.0 if tip < 100.0
            name = "#{C::JOIN_DEFN_PREFIX} h#{tip.round}"
            defn = model.definitions[name]
            if defn.nil? || defn.image?
              defn = model.definitions.add(name)
            end
            defn.entities.clear! if defn.entities.size > 0
            half = C::HALF_POST_MM.mm
            add_box!(
              defn.entities,
              Geom::Point3d.new(-half, -half, 0),
              Geom::Point3d.new(half, half, tip.mm),
              Sketchup::Color.new(*C::POST_RGB),
              C::GROUP_POST
            )
            defn
          end

          # Snap wall_b to wall_a at 90° with a 37mm join post in the OUTER corner pocket.
          # Plan (join-90-plan.png): red post at outer corner; blue Al butts post faces
          # (no overlap); outer edges flush with post outer faces; purple graphics INSIDE.
          def join_walls_at_right_angle!(wall_a, wall_b)
            return false unless wall_a && wall_a.valid? && wall_b && wall_b.valid?
            return false if wall_a.entityID == wall_b.entityID
            model = wall_a.model
            ha = wall_height_key(wall_a)
            hb = wall_height_key(wall_b)
            tip_h = [post_tip_mm(ha), post_tip_mm(hb)].min
            half = C::HALF_POST_MM

            # A's viewer-right outer tip (local x=0 end face centre).
            tip = viewer_right_tip_world(wall_a)
            z = Floorspace.module_base_z(model)
            tip = Geom::Point3d.new(tip.x, tip.y, z)

            xa = wall_a.transformation.xaxis
            ya = wall_a.transformation.yaxis
            begin
              xa.length = 1.0
              ya.length = 1.0
            rescue StandardError
              xa = Geom::Vector3d.new(-1, 0, 0)
              ya = Geom::Vector3d.new(0, -1, 0)
            end

            # Outer-corner pocket: past A's end only, SAME Y span as posts
            #   x ∈ [-POST, 0], y ∈ [-half, +half]
            # → outer faces of A and join flush at y=−half; A end butts x=0.
            # Inner vertex of join (where both frame ends meet) = tip + ya*half.
            join_centre = Geom::Point3d.new(
              tip.x - xa.x * half.mm,
              tip.y - xa.y * half.mm,
              z
            )

            # B runs along +ya (front / inside of L). Graphic faces +xa (toward A /
            # into the corner). Handedness is LH so purple stays on the inside.
            xb = Geom::Vector3d.new(ya.x, ya.y, 0)
            yb = Geom::Vector3d.new(xa.x, xa.y, 0)
            zb = Geom::Vector3d.new(0, 0, 1)
            begin
              xb.length = 1.0
              yb.length = 1.0
            rescue StandardError
              xb = Geom::Vector3d.new(0, -1, 0)
              yb = Geom::Vector3d.new(-1, 0, 0)
            end

            # B's local-0 outer face flushes with join's +ya face (inner vertex side).
            join_b_face = Geom::Point3d.new(
              join_centre.x + ya.x * half.mm,
              join_centre.y + ya.y * half.mm,
              z
            )
            # origin at connecting tip → B body extends +xb away from join.
            origin_b = join_b_face
            wall_b.transformation = Geom::Transformation.new(xb, yb, zb, origin_b)
            Constraints.snap_floor_sitting_to_floor!(wall_b)

            defn = join_post_definition!(model, tip_h)
            tr_j = Geom::Transformation.new(xa, ya, zb, join_centre)
            join = model.active_entities.add_instance(defn, tr_j)
            join.name = C::JOIN_INSTANCE_NAME
            Attributes.set_many(join, {
              ::ISOframe::StandDesigner::Constants::KEY_RANGE =>
                ::ISOframe::StandDesigner::Constants::RANGE_FABRIC,
              ::ISOframe::StandDesigner::Constants::KEY_TYPE =>
                ::ISOframe::StandDesigner::Constants::TYPE_FABRIC_JOIN,
              ::ISOframe::StandDesigner::Constants::KEY_HEIGHT =>
                (tip_h <= post_tip_mm(ha) ? ha : hb).to_s,
              ::ISOframe::StandDesigner::Constants::KEY_FLOOR_SLIDE => '1'
            })
            Constraints.mark_floor_slide!(join)
            Constraints.snap_floor_sitting_to_floor!(join)
            join
          end

          def definition_name(width_mm, height_key)
            "#{C::DEFN_PREFIX} #{height_key} w#{width_mm.round}"
          end

          # Always rebuild — Frame Size make_unique can leave a def named w900
          # with a wider body; Place must never reuse that stale geometry.
          def definition_for!(model, width_mm, height_key)
            width = snap_width_mm(width_mm)
            hkey = height_key.to_s
            hkey = C::DEFAULT_HEIGHT unless C::HEIGHTS_MM.key?(hkey)
            name = definition_name(width, hkey)
            defn = model.definitions[name]
            if defn.nil? || defn.image?
              defn = model.definitions.add(name)
            end
            rebuild!(defn, width, hkey)
            ensure_definition_name!(defn, width, hkey)
            defn
          end

          def ensure_definition_name!(defn, width_mm, height_key)
            return unless defn && defn.valid?
            want = definition_name(snap_width_mm(width_mm), height_key)
            defn.name = want if defn.name.to_s != want
          rescue StandardError => e
            puts "[ISOframe][Fabric] rename def failed: #{e.message}"
          end

          # Drop unused Fabric defs so a deleted resized wall cannot poison Place.
          def purge_unused_fabric_defs!(model)
            return unless model
            model.definitions.purge_unused
          rescue StandardError => e
            puts "[ISOframe][Fabric] purge_unused failed: #{e.message}"
          end

          # Post centres (mm): outer faces at 0 and width (true edge-to-edge).
          # Starter bay packs at viewer-LEFT (local width); extensions toward
          # viewer-RIGHT (local 0). First extension post is 900 mm from left edge.
          def post_centres_mm(width_mm)
            width = snap_width_mm(width_mm)
            segs = decompose_width_mm(width)
            half = C::HALF_POST_MM
            # Walk from left outer (local width) down to right outer (local 0).
            edges = [width.to_f]
            segs.each { |s| edges << (edges.last - s.to_f) }
            centres = []
            edges.each_with_index do |e, i|
              if i.zero?
                centres << (width - half)
              elsif i == edges.size - 1
                centres << half
              else
                centres << e
              end
            end
            centres.reverse # ascending local X for rebuild loops
          end

          def brace_z_list(height_key)
            C::BRACE_Z_MM[height_key.to_s] || C::BRACE_Z_MM[C::DEFAULT_HEIGHT]
          end

          def rebuild!(defn, width_mm, height_key)
            defn.entities.clear! if defn.entities.size > 0
            width = snap_width_mm(width_mm)
            hkey = height_key.to_s
            hkey = C::DEFAULT_HEIGHT unless C::HEIGHTS_MM.key?(hkey)
            tip = post_tip_mm(hkey)
            g_h = height_mm(hkey)
            z_bot = C::GRAPHIC_Z_BOT_MM.mm
            z_top = g_h.mm

            centres = post_centres_mm(width)
            # Vertical Al posts — soles at local Z=0 (floorspace top).
            centres.each_with_index do |x_mm, i|
              add_post!(defn.entities, x_mm.mm, tip, "#{C::GROUP_POST}_#{i}")
            end
            x_left = centres.first
            x_right = centres.last
            add_top_rail!(defn.entities, x_left.mm, x_right.mm, tip, C::GROUP_RAIL_TOP)
            add_bottom_rail!(defn.entities, x_left.mm, x_right.mm, C::GROUP_RAIL_BOT)

            # Round braces between consecutive posts (length = centre span = bay−37).
            zs = brace_z_list(hkey)
            (0...(centres.size - 1)).each do |i|
              x0 = centres[i]
              x1 = centres[i + 1]
              zs.each_with_index do |z_mm, zi|
                next if z_mm >= tip
                add_brace!(
                  defn.entities,
                  x0.mm,
                  x1.mm,
                  z_mm,
                  "#{C::GROUP_BRACE}_#{i}_#{zi}"
                )
              end
            end

            # Fabric covers full outer-to-outer frame (0 … width), Z≥0.
            add_graphic_panel!(
              defn.entities,
              0.0,
              width.mm,
              z_bot,
              z_top,
              C::GROUP_GRAPHIC
            )
            ensure_definition_name!(defn, width, hkey)
            defn
          end

          def add_post!(ents, x, tip_mm, name)
            half = C::HALF_POST_MM.mm
            tip = tip_mm.mm
            add_box!(
              ents,
              Geom::Point3d.new(x - half, -half, 0),
              Geom::Point3d.new(x + half, half, tip),
              Sketchup::Color.new(*C::POST_RGB),
              name
            )
          end

          def add_top_rail!(ents, x_c0, x_c1, tip_mm, name)
            half = C::HALF_POST_MM.mm
            tip = tip_mm.mm
            rail = C::POST_MM.mm
            z0 = tip - rail
            z0 = 0 if z0 < 0
            add_box!(
              ents,
              Geom::Point3d.new(x_c0 - half, -half, z0),
              Geom::Point3d.new(x_c1 + half, half, tip),
              Sketchup::Color.new(*C::POST_RGB),
              name
            )
          end

          def add_bottom_rail!(ents, x_c0, x_c1, name)
            half = C::HALF_POST_MM.mm
            rail = C::POST_MM.mm
            add_box!(
              ents,
              Geom::Point3d.new(x_c0 - half, -half, 0),
              Geom::Point3d.new(x_c1 + half, half, rail),
              Sketchup::Color.new(*C::POST_RGB),
              name
            )
          end

          # 12.5 mm round Al brace along +X at Z=z_mm, Y=0 (post plane centre).
          # Length = x1 − x0 (= module/bay width − 37 mm between end-post centres).
          def add_brace!(ents, x0, x1, z_mm, name)
            return if x1 <= x0
            r = (C::BRACE_DIAMETER_MM / 2.0).mm
            z = z_mm.to_f.mm
            y = 0.0
            n = C::BRACE_SEGMENTS
            ring0 = []
            ring1 = []
            n.times do |i|
              ang = (2.0 * Math::PI * i) / n
              dy = r * Math.cos(ang)
              dz = r * Math.sin(ang)
              ring0 << Geom::Point3d.new(x0, y + dy, z + dz)
              ring1 << Geom::Point3d.new(x1, y + dy, z + dz)
            end
            group = ents.add_group
            group.name = name
            color = Sketchup::Color.new(*C::BRACE_RGB)
            group.entities.add_face(ring0)
            group.entities.add_face(ring1.reverse)
            n.times do |i|
              j = (i + 1) % n
              group.entities.add_face(ring0[i], ring0[j], ring1[j], ring1[i])
            end
            group.entities.grep(Sketchup::Face).each do |f|
              f.material = color
              f.back_material = color
            end
            group
          rescue StandardError => e
            puts "[ISOframe][Fabric] add_brace! failed: #{e.message}"
            nil
          end

          def add_graphic_panel!(ents, x0, x1, z_bot, z_top, name)
            return if x1 <= x0 || z_top <= z_bot
            y0 = C::HALF_POST_MM.mm + C::GRAPHIC_FRONT_CLEARANCE_MM.mm
            y1 = y0 + C::GRAPHIC_THICKNESS_MM.mm
            add_box!(
              ents,
              Geom::Point3d.new(x0, y0, z_bot),
              Geom::Point3d.new(x1, y1, z_top),
              Sketchup::Color.new(*C::GRAPHIC_RGB),
              name
            )
          rescue StandardError => e
            puts "[ISOframe][Fabric] add_graphic_panel! failed: #{e.message}"
          end

          def add_box!(ents, pmin, pmax, color, name)
            group = ents.add_group
            group.name = name
            x0, y0, z0 = pmin.x, pmin.y, pmin.z
            x1, y1, z1 = pmax.x, pmax.y, pmax.z
            z0 = 0 if z0 < 0
            z1 = 0 if z1 < 0
            return group if z1 <= z0
            bot = [
              Geom::Point3d.new(x0, y0, z0),
              Geom::Point3d.new(x1, y0, z0),
              Geom::Point3d.new(x1, y1, z0),
              Geom::Point3d.new(x0, y1, z0)
            ]
            top = [
              Geom::Point3d.new(x0, y0, z1),
              Geom::Point3d.new(x1, y0, z1),
              Geom::Point3d.new(x1, y1, z1),
              Geom::Point3d.new(x0, y1, z1)
            ]
            faces = []
            faces << group.entities.add_face(bot[0], bot[1], bot[2], bot[3])
            faces << group.entities.add_face(top[0], top[3], top[2], top[1])
            4.times do |i|
              j = (i + 1) % 4
              faces << group.entities.add_face(bot[i], bot[j], top[j], top[i])
            end
            faces.compact.each do |f|
              next unless f
              f.material = color
              f.back_material = color
            end
            group
          rescue StandardError => e
            puts "[ISOframe][Fabric] add_box! failed: #{e.message}"
            group
          end

          def wall_local_width_mm(inst)
            Attributes.get(inst, ::ISOframe::StandDesigner::Constants::KEY_FABRIC_WIDTH_MM, C::STARTER_WIDTH_MM).to_f
          end

          def wall_height_key(inst)
            Attributes.get(inst, ::ISOframe::StandDesigner::Constants::KEY_HEIGHT, C::DEFAULT_HEIGHT).to_s
          end
        end
      end
    end
  end
end
