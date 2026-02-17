require 'glimmer-dsl-libui'
require 'json'
require 'date'

class LuckyKoi
  include Glimmer
  FILE_NAME = 'lucky_koi_vault.json'

  def initialize
    @currency = "$"
    @balance, @income_baseline, @transactions = 0.0, 0.0, []
    @selected_index = nil
    load_data
    @income_baseline <= 0 ? launch_setup_window : launch_main_app
  end

  # --- 1. DATA: 10 GLOBAL MISSIONS ---
  def all_missions
    [
      { tier: "Foundation", name: "The 48-Hour Rule", goal: "No impulse > 5% of pay.", advice: "Wait 48 hours before buying non-essentials." },
      { tier: "Foundation", name: "Subscription Audit", goal: "Cancel 2 unused services.", advice: "Small recurring leaks drain wealth." },
      { tier: "Foundation", name: "Budget Benchmark", goal: "Track 30 days of history.", advice: "Management requires measurement." },
      { tier: "Security", name: "1-Month Anchor", goal: "Balance >= Baseline.", advice: "Your first month of savings is your safety net." },
      { tier: "Security", name: "The 50/30/20 Rule", goal: "Needs < 50% of Income.", advice: "Fixed costs shouldn't exceed half of pay." },
      { tier: "Security", name: "Insurance Shield", goal: "Health/Life setup.", advice: "Protect your downside from emergencies." },
      { tier: "Growth", name: "3-Month Shield", goal: "Ratio >= 3.0x.", advice: "Survive a job loss without stress." },
      { tier: "Growth", name: "Investment Seed", goal: "Automate 10% to Assets.", advice: "Let compound interest begin its work." },
      { tier: "Mastery", name: "6-Month Fortress", goal: "Ratio >= 6.0x.", advice: "You are now financially bulletproof." },
      { tier: "Mastery", name: "Freedom Year", goal: "Ratio >= 12.0x.", advice: "One year of life saved. Take major risks." }
    ]
  end

  def current_suggested_mission
    r = current_ratio
    return all_missions[0] if @transactions.size < 5
    if r < 0.5 then all_missions[1]
    elsif r < 1.0 then all_missions[3]
    elsif r < 2.0 then all_missions[4]
    elsif r < 3.0 then all_missions[6]
    elsif r < 5.0 then all_missions[7]
    elsif r < 10.0 then all_missions[8]
    else all_missions[9]
    end
  end

  # --- 2. SETUP MODAL ---
  def launch_setup_window
    @setup_win = window('Setup', 350, 150) {
      margined true
      vertical_box {
        label("Monthly Income Baseline:")
        @setup_input = entry
        button("Confirm & Open") {
          on_clicked {
            val = @setup_input.text.to_f
            if val > 0
              @income_baseline = val; save_data; @setup_win.destroy; launch_main_app
            else
              msg_box('Error', 'Baseline must be > 0')
            end
          }
        }
      }
    }
    @setup_win.show
  end

  # --- 3. MAIN APP ---
  def launch_main_app
    @main_window = window('LuckyKoi: Sovereign Architect 🎏', 1050, 900) {
      margined true
      vertical_box {
        tab {
          stretchy true

          tab_item('📊 Analytics') {
            vertical_box {
              padded true
              
              # --- REAL-TIME VISUAL BAR ---
              group('💹 Real-Time Savings Efficiency (Income vs Expenses)') {
                stretchy false
                vertical_box {
                  @efficiency_bar = progress_bar
                  @efficiency_lbl = label("Efficiency: 0%")
                }
              }

              horizontal_box {
                stretchy false
                group('🎎 Identity') {
                  vertical_box {
                    @rank_lbl = label("RANK: #{calculate_rank}")
                    @ratio_lbl = label("Ratio: #{current_ratio}x")
                    @impulse_lbl = label("Impulse-Free: #{days_since_big_spend} Days")
                  }
                }
                group('🎯 Active Mission') {
                  vertical_box {
                    @active_m_lbl = label("MISSION: #{current_suggested_mission[:name]}")
                    @active_g_lbl = label("GOAL: #{current_suggested_mission[:goal]}", size: 10)
                  }
                }
              }

              # --- FIXED UI TEXTBOXES ---
              group('🧧 Management') {
                stretchy false
                vertical_box {
                  padded true
                  horizontal_box {
                    # Fixed width container for Amount
                    vertical_box { 
                      label 'Amount:'
                      horizontal_box { @amt_in = entry; stretchy false } 
                      stretchy false 
                    } 
                    # Stretching container for Details
                    vertical_box { 
                      label 'Details:'
                      @desc_in = entry 
                      stretchy true 
                    }
                  }
                  horizontal_box {
                    button('✨ Income') { on_clicked { handle_entry(:inc) } }
                    button('💢 Expense') { on_clicked { handle_entry(:exp) } }
                    @save_btn = button('💾 Save Edit') { enabled false; on_clicked { save_edit } }
                    @del_btn = button('🗑️ Delete') { enabled false; on_clicked { run_delete } }
                  }
                }
              }

              @hist_table = table {
                text_column('Type'); text_column('Details'); text_column('Amount'); text_column('Date')
                cell_rows @transactions.map { |t| t.map(&:to_s) }
                on_selection_changed { |_, sel| @selected_index = sel; load_selection if sel }
              }
            }
          }

          tab_item('🏆 Tracker') {
            vertical_box {
              padded true
              group('📍 Your Strategy') {
                vertical_box {
                  @m_title = label("MISSION: #{current_suggested_mission[:name]}", size: 14)
                  @m_advice = label("ADVICE: #{current_suggested_mission[:advice]}")
                }
              }
              
              table {
                text_column('Tier'); text_column('Mission'); text_column('Goal')
                cell_rows all_missions.map { |m| [m[:tier], m[:name], m[:goal]] }
              }
            }
          }

          tab_item('⚙️ Settings') {
            vertical_box {
              padded true
              label "Baseline: #{@income_baseline}"
              horizontal_box {
                @new_base = entry
                button("Update") { on_clicked { @income_baseline = @new_base.text.to_f; update_ui } }
                stretchy false
              }
              button("Wipe All Data") { on_clicked { reset_all } }
            }
          }
        }
      }
      on_closing { destroy; exit }
    }
    update_ui
    @main_window.show
  end

  # --- 4. CORE LOGIC ---
  def handle_entry(type)
    val = @amt_in.text.to_f
    return if val <= 0
    @balance += (type == :inc ? val : -val)
    @transactions << [(type == :inc ? "🟢 INC" : "🔴 EXP"), @desc_in.text, (type == :inc ? "+#{val}" : "-#{val}"), Date.today.to_s]
    update_ui; clear_inputs
  end

  def update_ui
    total_inc = @transactions.select { |t| t[2].to_f > 0 }.map { |t| t[2].to_f }.sum
    total_exp = @transactions.select { |t| t[2].to_f < 0 }.map { |t| t[2].to_f.abs }.sum
    
    # Update Efficiency Bar (0 to 100)
    efficiency = total_inc > 0 ? (([total_inc - total_exp, 0].max / total_inc) * 100).to_i : 0
    @efficiency_bar.value = efficiency
    @efficiency_lbl.text = "Efficiency: #{efficiency}% of income retained as savings"

    @rank_lbl.text = "RANK: #{calculate_rank}"
    @ratio_lbl.text = "Ratio: #{current_ratio}x"
    @impulse_lbl.text = "Impulse-Free: #{days_since_big_spend} Days"
    
    m = current_suggested_mission
    @active_m_lbl.text = "MISSION: #{m[:name]}"
    @active_g_lbl.text = "GOAL: #{m[:goal]}"
    @m_title.text = "MISSION: #{m[:name]}" rescue nil
    @m_advice.text = "ADVICE: #{m[:advice]}" rescue nil
    
    @hist_table.cell_rows = @transactions.map { |t| t.map(&:to_s) }
    save_data
  end

  def current_ratio; @income_baseline > 0 ? (@balance / @income_baseline).round(2) : 0; end
  def calculate_rank; r = current_ratio; (r >= 12 ? "Celestial Dragon 🏮" : r >= 6 ? "Golden Dragon 🐉" : r >= 1 ? "Great Nishiki 🐠" : "Little Fry 🐟"); end

  def days_since_big_spend
    limit = @income_baseline * 0.05
    big_spends = @transactions.select { |t| t[2].to_f < 0 && t[2].to_f.abs > limit }
    big_spends.empty? ? "N/A" : (Date.today - Date.parse(big_spends.last[3])).to_i
  end

  def load_selection
    row = @transactions[@selected_index]
    @amt_in.text = row[2].gsub(/[+-]/, ''); @desc_in.text = row[1]
    @save_btn.enabled = @del_btn.enabled = true
  end

  def save_edit; run_delete(false); handle_entry(@amt_in.text.to_f > 0 ? :inc : :exp); end
  def run_delete(refresh = true); return unless @selected_index; @balance -= @transactions[@selected_index][2].to_f; @transactions.delete_at(@selected_index); update_ui if refresh; clear_inputs if refresh; end
  def clear_inputs; @selected_index = nil; @amt_in.text = ''; @desc_in.text = ''; @save_btn.enabled = @del_btn.enabled = false; end
  def save_data; File.write(FILE_NAME, JSON.generate({bal: @balance, inc: @income_baseline, tx: @transactions})); end
  def load_data; return unless File.exist?(FILE_NAME); d = JSON.parse(File.read(FILE_NAME)); @balance, @income_baseline, @transactions = d['bal'], d['inc'], d['tx']; end
  def reset_all; @balance = 0.0; @income_baseline = 0.0; @transactions = []; save_data; @main_window.destroy; launch_setup_window; end
end

LuckyKoi.new
