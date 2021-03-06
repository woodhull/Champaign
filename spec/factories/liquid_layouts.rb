FactoryGirl.define do

  factory :liquid_layout do
    title { Faker::Company.bs }
    content "<div class='fun'></div>"
    description { Faker::Lorem.sentence }
    experimental false

    trait :default do
      title 'default'
      content %{ {% include 'petition' %} {% include 'thermometer' %} }
    end

    trait :petition do
      title 'petition template'
      content %{ {% include 'petition' %} }
    end

    trait :thermometer do
      title 'thermometer template'
      content %{ {% include 'thermometer' %} }
    end

    trait :no_plugins do
      title 'layout with no plugins'
      content %{ whatever }
    end

    trait :experimental do
      title 'Experimental template'
      experimental true
    end

    trait :post_action_share_layout do
      title 'post action share template'
      content %{
              <div class="share-buttons">
                {% unless shares['facebook'] == blank %}
                  <div class="share-buttons__button button--facebook {{ shares['facebook'] }}"></div>
                {% endunless %}
                {% unless shares['twitter'] == blank %}
                  <div class="share-buttons__button button--twitter {{ shares['twitter'] }}"></div>
                {% endunless %}
                {% unless shares['email'] == blank %}
                  <div class="share-buttons__simple-email-link {{ shares['email'] }}"></div>
                {% endunless %}
              </div>
              }

    end
  end

end
