-- @description IFLS WB: AutoSplit Mixed Content (analyze -> split into HIT/TEX chunks)
-- @version 1.0.3
-- @author IFLS Workbench
-- @about Analyzes selected audio items and splits them into HIT_/TEX_/MIX_ chunks using transient density, duration and confidence scoring (fieldrec mixed content).
-- @provides [main] .


local r = reaper

local function msg(s) r.ShowConsoleMsg(tostring(s).."\n") end
local function clamp(x,a,b) if x<a then return a elseif x>b then return b else return x end end
local function db_to_amp(db) return 10^(db/20) end
local function amp_to_db(a) if a<=0 then return -150 end return 20*math.log(a,10) end

local function get_take(item)
  local take = r.GetActiveTake(item)
  if not take or r.TakeIsMIDI(take) then return nil end
  return take
end

local function analyze_regions(take, item_pos, item_len, cfg)
  local sr = cfg.samplerate
  local nch = cfg.channels
  local block = cfg.block
  local hop = cfg.hop

  local aa = r.CreateTakeAudioAccessor(take)
  if not aa then return {} end

  local t0 = item_pos
  local t1 = item_pos + item_len
  local gate_amp = db_to_amp(cfg.gate_db)
  local peak_gate_amp = db_to_amp(cfg.peak_gate_db)

  local buf = r.new_array(block*nch)
  local regions = {}

  local in_active = false
  local reg = nil
  local last_active_t = t0

  local function push_region(x)
    if not x then return end
    x.dur = x.t_end - x.t_start
    if x.dur >= cfg.min_region_s then
      regions[#regions+1] = x
    end
  end

  local t = t0
  while t < t1 do
    buf.clear()
    local ok = r.GetAudioAccessorSamples(aa, sr, nch, t, math.floor(block), buf)
    if ok <= 0 then break end

    local arr = buf.table()
    local sumsq, peak = 0.0, 0.0
    local n = ok * nch
    for i=1,n do
      local v = math.abs(arr[i])
      sumsq = sumsq + v*v
      if v > peak then peak = v end
    end
    local rms = math.sqrt(sumsq / math.max(1,n))
    local active = (rms >= gate_amp)

    if active then
      last_active_t = t
      if not in_active then
        in_active = true
        reg = { t_start = t, t_end = t + (ok/sr), blocks=0, trans=0, peak_max=0.0 }
      end
    end

    if in_active then
      reg.t_end = t + (ok/sr)
      reg.blocks = reg.blocks + 1
      if peak > reg.peak_max then reg.peak_max = peak end

      local crest_db = amp_to_db(peak) - amp_to_db(rms)
      if peak >= peak_gate_amp and crest_db >= cfg.crest_db then
        reg.trans = reg.trans + 1
      end

      if (not active) and ((t - last_active_t) >= cfg.silence_gap_s) then
        in_active = false
        push_region(reg)
        reg = nil
      end
    end

    t = t + (hop/sr)
  end
  if in_active then push_region(reg) end
  r.DestroyAudioAccessor(aa)

  -- merge close regions
  if #regions >= 2 then
    table.sort(regions, function(a,b) return a.t_start < b.t_start end)
    local merged = {}
    local cur = regions[1]
    for i=2,#regions do
      local nxt = regions[i]
      local gap = nxt.t_start - cur.t_end
      if gap <= cfg.merge_gap_s then
        cur.t_end = nxt.t_end
        cur.blocks = cur.blocks + nxt.blocks
        cur.trans = cur.trans + nxt.trans
        cur.peak_max = math.max(cur.peak_max, nxt.peak_max or 0.0)
      else
        merged[#merged+1] = cur
        cur = nxt
      end
    end
    merged[#merged+1] = cur
    regions = merged
  end

  -- classify (confidence scoring)
  -- score_hit favors short duration + higher transient density
  -- score_tex favors long duration + lower transient density
  for _,rg in ipairs(regions) do
    rg.dur = rg.t_end - rg.t_start
    local td = (rg.blocks>0) and (rg.trans/rg.blocks) or 0.0
    rg.transient_density = td

    local dur_hit = 0.0
    if rg.dur <= cfg.hit_max_len_s then
      dur_hit = 1.0
    elseif rg.dur >= cfg.hit_soft_max_s then
      dur_hit = 0.0
    else
      dur_hit = 1.0 - ((rg.dur - cfg.hit_max_len_s) / math.max(1e-9, (cfg.hit_soft_max_s - cfg.hit_max_len_s)))
    end

    local dens_hit = 0.0
    local dens_ref_hi = math.max(cfg.hit_transient_density + 1e-6, cfg.density_hi or 0.45)
    if td <= cfg.hit_transient_density then
      dens_hit = 0.0
    elseif td >= dens_ref_hi then
      dens_hit = 1.0
    else
      dens_hit = (td - cfg.hit_transient_density) / (dens_ref_hi - cfg.hit_transient_density)
    end

    local score_hit = (cfg.w_dur_hit or 0.60)*dur_hit + (cfg.w_dens_hit or 0.40)*dens_hit
    local score_tex = (cfg.w_dur_tex or 0.60)*(1.0-dur_hit) + (cfg.w_dens_tex or 0.40)*(1.0-dens_hit)

    rg.score_hit = score_hit
    rg.score_tex = score_tex
    rg.confidence = math.abs(score_hit - score_tex) -- 0..1

    rg.type = (score_hit >= score_tex) and "HIT" or "TEX"
    if rg.confidence < (cfg.confidence_threshold or 0.22) then
      rg.type = "MIX"
    end
  end

  return regions
end

local function split_item_into_regions(item, regions, cfg, out_items)
  if #regions == 0 then return 0 end

  local tr = r.GetMediaItem_Track(item)
  local item_pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = r.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_end = item_pos + item_len

  local segs = {}
  for _,rg in ipairs(regions) do
    local s = clamp(rg.t_start - cfg.pad_s, item_pos, item_end)
    local e = clamp(rg.t_end + cfg.pad_s, item_pos, item_end)
    if (e - s) >= cfg.min_keep_s then
      segs[#segs+1] = {s=s, e=e, typ=rg.type}
    end
  end
  if #segs == 0 then return 0 end
  table.sort(segs, function(a,b) return a.s < b.s end)

  local created = 0
  local cur = item

  -- drop pre-silence
  if segs[1].s > item_pos + 1e-9 then
    local right = r.SplitMediaItem(cur, segs[1].s)
    if right then
      r.DeleteTrackMediaItem(tr, cur)
      cur = right
    end
  end

  for i,seg in ipairs(segs) do
    local seg_end = seg.e
    local cur_pos = r.GetMediaItemInfo_Value(cur, "D_POSITION")
    local cur_len = r.GetMediaItemInfo_Value(cur, "D_LENGTH")
    local cur_end = cur_pos + cur_len

    local right = nil
    if seg_end < cur_end - 1e-9 then
      right = r.SplitMediaItem(cur, seg_end)
    end

    local take = r.GetActiveTake(cur)
    if take and not r.TakeIsMIDI(take) and cfg.tag_names then
      local _, nm = r.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
      nm = (nm and nm ~= "") and nm or "chunk"
      r.GetSetMediaItemTakeInfo_String(take, "P_NAME", seg.typ .. "_" .. nm, true)
    end

    if out_items then out_items[#out_items+1] = cur end
    created = created + 1

    if i < #segs then
      local next_start = segs[i+1].s
      if right then
        if next_start > seg_end + 1e-9 then
          local right2 = r.SplitMediaItem(right, next_start)
          if right2 then
            r.DeleteTrackMediaItem(tr, right)
            cur = right2
          else
            cur = right
          end
        else
          cur = right
        end
      end
    else
      if right then r.DeleteTrackMediaItem(tr, right) end
    end
  end

  return created
end

local function main()
  local cfg = {
    samplerate = 12000,
    channels = 2,
    block = 512,
    hop = 256,
    gate_db = -55.0,
    peak_gate_db = -35.0,
    crest_db = 14.0,
    silence_gap_s = 0.12,
    merge_gap_s = 0.06,
    min_region_s = 0.06,
    pad_s = 0.008,
    min_keep_s = 0.03,
    hit_max_len_s = 1.25,
    hit_soft_max_s = 2.50,
    hit_transient_density = 0.22,
    tag_names = true,
    confidence_threshold = 0.22,
    density_hi = 0.45,
    w_dur_hit = 0.60,
    w_dens_hit = 0.40,
    w_dur_tex = 0.60,
    w_dens_tex = 0.40,
  }
  local cnt = r.CountSelectedMediaItems(0)
  if cnt == 0 then
    r.MB("Select one or more audio items to analyze & split.", "IFLSWB AutoSplit", 0)
    return
  end

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  local items = {}
  for i=0,cnt-1 do items[#items+1] = r.GetSelectedMediaItem(0, i) end

  local total_created = 0
  local out_items = {}

  for _,item in ipairs(items) do
    local take = get_take(item)
    if take then
      local pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
      local len = r.GetMediaItemInfo_Value(item, "D_LENGTH")
      if len > 0.01 then
        local regions = analyze_regions(take, pos, len, cfg)
        total_created = total_created + split_item_into_regions(item, regions, cfg, out_items)
      end
    end
  end

  -- select created chunks for convenience
  r.SelectAllMediaItems(0, false)
  for _,it in ipairs(out_items) do
    r.SetMediaItemSelected(it, true)
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("IFLS WB: AutoSplit Mixed Content", -1)

  msg(("AutoSplit complete. Created %d chunk items."):format(total_created))
end

main()