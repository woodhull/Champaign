include ActionView::Helpers::NumberHelper

class Plugins::Thermometer < ActiveRecord::Base
  belongs_to :page, touch: true

  DEFAULTS = { offset: 0, goal: 100 }

  validates :goal, :offset, presence: true
  validates :goal, :offset, numericality: { greater_than_or_equal_to: 0 }

  def current_total
    offset + page.action_count
  end

  def current_progress
    update_goal if goal_should_update
    current_total / goal.to_f * 100
  end

  def liquid_data(supplemental_data={})
    attributes.merge(
      percentage: current_progress,
      remaining: number_with_delimiter(goal - current_total),
      signatures: number_with_delimiter(current_total),
      goal_k: abbreviate_number(goal)
    )
  end

  def name
    self.class.name.demodulize
  end

  def update_goal
    increment!(:goal, determine_next_goal - goal)
  end

  private

  def abbreviate_number(number)
    return number.to_s if number < 1000
    return "#{(goal / 1000).to_i}k" if number < 1_000_000
    locale = page.try(:language).try(:code)
    return "%g #{I18n.t('thermometer.million', locale: locale)}" % (goal / 1_000_000.0).round(1)
  end

  def goal_should_update
    current_total >= goal
  end

  def determine_next_goal
    target_jump = determine_target_jump(self.current_total)


    # This is slight overkill; it makes sure that when we increment the goal, it's targeting the closest jump value.
    # Essentially, the goal here is to make sure that if we somehow don't update the goal right when it's on the next
    # step (like 200 or 10000) we don't end up with an ugly goal like 301.
    new_goal = current_total + target_jump
    goal_target_difference = new_goal % target_jump
    target_midpoint = target_jump * 0.5

    if goal_target_difference == 0
      new_goal
    elsif goal_target_difference <= target_midpoint
      new_goal - goal_target_difference
    else
      new_goal + target_jump - (goal_target_difference)
    end
  end

  def determine_target_jump(count)
    # We use a target jump here that's intended to bring us to round, pyschologically appealing
    # numbers. People tend to react better seeing 25000 as a target than something like 22500, even
    # if the latter is closer. So, this method defines a set of steps for the number to jump, based
    # on the given value.
    case
    when count < 500
      100
    when count < 10_000
      1000
    when count < 25_000
      5000
    when count < 100_000
      25_000
    when count < 250_000
      50_000
    when count < 1_000_000
      250_000
    when count < 2_000_000
      500_000
    else
      1_000_000
    end
  end
end
