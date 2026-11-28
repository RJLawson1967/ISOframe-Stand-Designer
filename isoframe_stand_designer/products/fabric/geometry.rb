# frozen_string_literal: true
# Procedural Fabric wall (v0.1.88) — 37mm Al frame + 12.5mm round braces, fabric cover.
# Width is outer-to-outer. snap_width keeps 900 base (never rounds 900→1000).

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
            # Same RH ψ=180° convention as Wave: graphic +Y faces floorspace (−world Y).
            Geom::Transformation.new(
              Geom::Vector3d.new(-1, 0, 0),
              Geom::Vector3d.new(0, -1, 0),
              Geom::Vector3d.new(0, 0, 1),
              origin
            )
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
          def post_centres_mm(width_mm)
            width = snap_width_mm(width_mm)
            segs = decompose_width_mm(width)
            half = C::HALF_POST_MM
            edges = [0.0]
            segs.each { |s| edges << (edges.last + s) }
            centres = []
            edges.each_with_index do |e, i|
              if i.zero?
                centres << half
              elsif i == edges.size - 1
                centres << (width - half)
              else
                centres << e
              end
            end
            centres
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
