# frozen_string_literal: true
# Wall module chain graph for hinge-flex propagation.
# Place writes module_id / prev / next / shared post ids (UX unchanged).
# Flex walks the free-side subtree and applies one rigid transform.

module ISOframe
  module StandDesigner
    module WallGraph
      module_function

      def new_id(prefix)
        "#{prefix}_#{Time.now.to_i}_#{rand(100_000..999_999)}"
      end

      def wave_modules(model)
        return [] unless model
        model.active_entities.grep(Sketchup::ComponentInstance).select do |inst|
          next false unless inst.valid?
          type = Attributes.get(inst, Constants::KEY_TYPE)
          next false unless type == Constants::TYPE_STARTER || type == Constants::TYPE_EXTENSION
          Attributes.get(inst, Constants::KEY_RANGE) == Constants::RANGE_WAVE
        end
      end

      def modules_on_wall(model, wall_id)
        return [] if wall_id.nil? || wall_id.to_s.empty?
        wave_modules(model).select do |inst|
          Attributes.get(inst, Constants::KEY_WALL).to_s == wall_id.to_s
        end
      end

      def ensure_module_identity!(inst)
        return unless inst && inst.valid?
        mid = Attributes.get(inst, Constants::KEY_MODULE_ID).to_s
        if mid.empty?
          mid = new_id('mod')
          Attributes.set(inst, Constants::KEY_MODULE_ID, mid)
        end
        ph = Attributes.get(inst, Constants::KEY_POST_HINGE).to_s
        if ph.empty?
          Attributes.set(inst, Constants::KEY_POST_HINGE, new_id('post'))
        end
        pf = Attributes.get(inst, Constants::KEY_POST_FREE).to_s
        if pf.empty?
          Attributes.set(inst, Constants::KEY_POST_FREE, new_id('post'))
        end
        mid
      end

      # Silent graph attrs on Place Starter (no UX change).
      def write_starter_graph!(inst)
        mid = new_id('mod')
        Attributes.set_many(inst, {
          Constants::KEY_MODULE_ID => mid,
          Constants::KEY_PREV_ID => '',
          Constants::KEY_NEXT_ID => '',
          Constants::KEY_POST_HINGE => new_id('post'),
          Constants::KEY_POST_FREE => new_id('post'),
          Constants::KEY_CHAIN_INDEX => 0
        })
        mid
      end

      # Silent graph attrs on Place Extension.
      # side :free  → append at anchor free post (new.hinge shares anchor.free).
      # side :hinge → prepend at anchor hinge (new.free shares anchor.hinge) so
      #               Place grows graphic-front RIGHT under RH ψ=180°.
      def write_extension_graph!(inst, anchor, side: :free)
        if side.to_s == 'hinge'
          write_extension_prepend_graph!(inst, anchor)
        else
          write_extension_append_graph!(inst, anchor)
        end
      end

      def write_extension_append_graph!(inst, anchor)
        ensure_module_identity!(anchor)
        mid = new_id('mod')
        anchor_free = Attributes.get(anchor, Constants::KEY_POST_FREE).to_s
        anchor_free = new_id('post') if anchor_free.empty?
        Attributes.set(anchor, Constants::KEY_POST_FREE, anchor_free) if Attributes.get(anchor, Constants::KEY_POST_FREE).to_s.empty?

        idx = Attributes.get(anchor, Constants::KEY_CHAIN_INDEX, 0).to_i + 1
        Attributes.set_many(inst, {
          Constants::KEY_MODULE_ID => mid,
          Constants::KEY_PREV_ID => Attributes.get(anchor, Constants::KEY_MODULE_ID).to_s,
          Constants::KEY_NEXT_ID => '',
          Constants::KEY_POST_HINGE => anchor_free, # shared joint with anchor free post
          Constants::KEY_POST_FREE => new_id('post'),
          Constants::KEY_CHAIN_INDEX => idx
        })
        Attributes.set(anchor, Constants::KEY_NEXT_ID, mid)
        mid
      end

      def write_extension_prepend_graph!(inst, root)
        ensure_module_identity!(root)
        mid = new_id('mod')
        root_hinge = Attributes.get(root, Constants::KEY_POST_HINGE).to_s
        if root_hinge.empty?
          root_hinge = new_id('post')
          Attributes.set(root, Constants::KEY_POST_HINGE, root_hinge)
        end

        model = root.model
        wall_id = Attributes.get(root, Constants::KEY_WALL)
        ordered_wall_modules(model, wall_id).each do |m|
          idx = Attributes.get(m, Constants::KEY_CHAIN_INDEX, 0).to_i
          Attributes.set(m, Constants::KEY_CHAIN_INDEX, idx + 1)
        end

        Attributes.set_many(inst, {
          Constants::KEY_MODULE_ID => mid,
          Constants::KEY_PREV_ID => '',
          Constants::KEY_NEXT_ID => Attributes.get(root, Constants::KEY_MODULE_ID).to_s,
          Constants::KEY_POST_HINGE => new_id('post'),
          Constants::KEY_POST_FREE => root_hinge, # shared joint with root hinge
          Constants::KEY_CHAIN_INDEX => 0
        })
        Attributes.set(root, Constants::KEY_PREV_ID, mid)
        mid
      end

      def find_by_module_id(model, module_id)
        return nil if module_id.nil? || module_id.to_s.empty?
        wave_modules(model).find do |inst|
          Attributes.get(inst, Constants::KEY_MODULE_ID).to_s == module_id.to_s
        end
      end

      # Place-continue tip module: the wall end that is graphic-front RIGHT.
      # Under RH ψ=180°, local free (follow next_*) is viewer LEFT — so this
      # returns the root / hinge tip instead. Flex walks still use prev/next.
      def free_end_module(inst)
        tip = place_continue_tip(inst)
        tip && tip[:module]
      end

      # { module:, side: :free|:hinge } for Place Extension snap / graph write.
      def place_continue_tip(inst)
        return nil unless inst && inst.valid?
        ensure_module_identity!(inst)
        model = inst.model
        wall_id = Attributes.get(inst, Constants::KEY_WALL)
        mods = modules_on_wall(model, wall_id)
        mods = [inst] if mods.empty?

        free_tip = chain_free_tip_module(inst) || geometric_free_end_module(inst) || inst
        root = chain_root_module(inst) || geometric_hinge_end_module(inst) || inst
        return { module: free_tip, side: :free } unless root && root.valid? && free_tip && free_tip.valid?

        right = Geometry.graphic_front_right_vector(free_tip)
        free_pt = Geometry.world_open_end(free_tip)
        hinge_pt = Geometry.world_hinge_end(root)
        if Geometry.plan_dot(free_pt, right) >= Geometry.plan_dot(hinge_pt, right)
          { module: free_tip, side: :free }
        else
          { module: root, side: :hinge }
        end
      end

      def chain_free_tip_module(inst)
        return nil unless inst && inst.valid?
        ensure_module_identity!(inst)
        model = inst.model
        cur = inst
        guard = 0
        nid = Attributes.get(cur, Constants::KEY_NEXT_ID).to_s
        while !nid.empty? && guard < 500
          nxt = find_by_module_id(model, nid)
          break unless nxt && nxt.valid?
          cur = nxt
          nid = Attributes.get(cur, Constants::KEY_NEXT_ID).to_s
          guard += 1
        end
        cur && cur.valid? ? cur : nil
      end

      def chain_root_module(inst)
        return nil unless inst && inst.valid?
        ensure_module_identity!(inst)
        model = inst.model
        cur = inst
        guard = 0
        pid = Attributes.get(cur, Constants::KEY_PREV_ID).to_s
        while !pid.empty? && guard < 500
          prv = find_by_module_id(model, pid)
          break unless prv && prv.valid?
          cur = prv
          pid = Attributes.get(cur, Constants::KEY_PREV_ID).to_s
          guard += 1
        end
        cur && cur.valid? ? cur : nil
      end

      def geometric_free_end_module(inst)
        return inst unless inst && inst.valid?
        model = inst.model
        wall_id = Attributes.get(inst, Constants::KEY_WALL)
        mods = modules_on_wall(model, wall_id)
        return inst if mods.size <= 1

        tol = Constants::POST_JOIN_TOL_MM.mm
        tip = mods.find do |cand|
          ca = Attributes.get(cand, Constants::KEY_FLEX, 0.0).to_f
          free_pt = Geometry.end_post_center_local(ca).transform(cand.transformation)
          mods.none? do |other|
            next false if other == cand
            hinge_pt = Geometry.hinge_center_local.transform(other.transformation)
            hinge_pt.distance(free_pt) <= tol
          end
        end
        tip || inst
      end

      def geometric_hinge_end_module(inst)
        return inst unless inst && inst.valid?
        model = inst.model
        wall_id = Attributes.get(inst, Constants::KEY_WALL)
        mods = modules_on_wall(model, wall_id)
        return inst if mods.size <= 1

        tol = Constants::POST_JOIN_TOL_MM.mm
        tip = mods.find do |cand|
          hinge_pt = Geometry.hinge_center_local.transform(cand.transformation)
          mods.none? do |other|
            next false if other == cand
            ca = Attributes.get(other, Constants::KEY_FLEX, 0.0).to_f
            free_pt = Geometry.end_post_center_local(ca).transform(other.transformation)
            free_pt.distance(hinge_pt) <= tol
          end
        end
        tip || inst
      end

      # Chain ordered starter → free tip (prev/next when present; else geometric).
      def ordered_wall_modules(model, wall_id)
        mods = modules_on_wall(model, wall_id)
        return [] if mods.empty?
        by_id = {}
        mods.each do |m|
          ensure_module_identity!(m)
          by_id[Attributes.get(m, Constants::KEY_MODULE_ID).to_s] = m
        end
        root = mods.find { |m| Attributes.get(m, Constants::KEY_PREV_ID).to_s.empty? }
        if root
          out = [root]
          nid = Attributes.get(root, Constants::KEY_NEXT_ID).to_s
          guard = 0
          while !nid.empty? && by_id[nid] && guard < 500
            nxt = by_id[nid]
            out << nxt
            nid = Attributes.get(nxt, Constants::KEY_NEXT_ID).to_s
            guard += 1
          end
          return out if out.size == mods.size
        end
        mods.sort_by { |m| Attributes.get(m, Constants::KEY_CHAIN_INDEX, 0).to_i }
      end

      # Modules that hang off the free side of `flexed` given hinge_side (:left/:right).
      # Prefers prev/next attrs; falls back to geometric post coincidence on same wall_id.
      def free_side_modules(flexed, hinge_side)
        return [] unless flexed && flexed.valid?
        model = flexed.model
        hinge_side = hinge_side.to_s
        hinge_side = Constants::HINGE_LEFT if hinge_side.empty?

        linked = walk_linked_free_side(flexed, hinge_side)
        return linked unless linked.empty?

        walk_geometric_free_side(flexed, hinge_side, model)
      end

      def walk_linked_free_side(flexed, hinge_side)
        model = flexed.model
        ensure_module_identity!(flexed)
        out = []
        if hinge_side == Constants::HINGE_LEFT
          # Free = local right → follow next_* toward open end.
          nid = Attributes.get(flexed, Constants::KEY_NEXT_ID).to_s
          while !nid.empty?
            nxt = find_by_module_id(model, nid)
            break unless nxt && nxt.valid?
            out << nxt
            nid = Attributes.get(nxt, Constants::KEY_NEXT_ID).to_s
          end
        else
          # Free = local left → follow prev_* toward starter / opposite end.
          pid = Attributes.get(flexed, Constants::KEY_PREV_ID).to_s
          while !pid.empty?
            prv = find_by_module_id(model, pid)
            break unless prv && prv.valid?
            out << prv
            pid = Attributes.get(prv, Constants::KEY_PREV_ID).to_s
          end
        end
        out
      end

      def walk_geometric_free_side(flexed, hinge_side, model)
        wall_id = Attributes.get(flexed, Constants::KEY_WALL)
        others = modules_on_wall(model, wall_id).reject { |i| i == flexed }
        return [] if others.empty?

        angle = Attributes.get(flexed, Constants::KEY_FLEX, 0.0).to_f
        posts = Geometry.semantic_posts(flexed, angle, hinge_side)
        seed = posts[:free_pt]
        tol = Constants::POST_JOIN_TOL_MM.mm
        remaining = others.dup
        frontier = [seed]
        moved = []
        visited = {}

        until frontier.empty?
          joint = frontier.shift
          remaining.dup.each do |cand|
            next if visited[cand.entityID]
            ca = Attributes.get(cand, Constants::KEY_FLEX, 0.0).to_f
            hinge_pt = Geometry.hinge_center_local.transform(cand.transformation)
            free_pt = Geometry.end_post_center_local(ca).transform(cand.transformation)
            attached = false
            next_joint = nil
            if hinge_side == Constants::HINGE_LEFT
              # Chain grows from flexed free onto cand hinge, then out cand free.
              if hinge_pt.distance(joint) <= tol
                attached = true
                next_joint = free_pt
              end
            else
              # Chain grows from flexed hinge-side (semantic free = local left)
              # onto cand free, then out cand hinge.
              if free_pt.distance(joint) <= tol
                attached = true
                next_joint = hinge_pt
              end
            end
            next unless attached
            visited[cand.entityID] = true
            remaining.delete(cand)
            moved << cand
            frontier << next_joint if next_joint
          end
        end
        moved
      end
    end
  end
end
