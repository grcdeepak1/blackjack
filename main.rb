require 'rubygems'
require 'sinatra'
require 'pry'
use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'grcdeepak1'

BLACKJACK_AMOUNT = 21
DEALER_MIN_HIT = 17

helpers do
	def calculate_total(cards) 
	  # [['H', '3'], ['S', 'Q'], ... ]
	  arr = cards.map{|e| e[1] }
	  total = 0
	  arr.each do |value|
	    if value == "A"
	      total += 11
	    elsif value.to_i == 0 # J, Q, K
	      total += 10
	    else
	      total += value.to_i
	    end
	  end

	  #correct for Aces
	  arr.select{|e| e == "A"}.count.times do
	    total -= 10 if total > 21
	  end
	  total
	end

	def card_image(card)
		suit = case card[0]
			when 'H' then 'hearts'
			when 'D' then 'diamonds'
			when 'S' then 'spades'
			when 'C' then 'clubs'
		end

		value = card[1]
		if ['J', 'Q', 'K', 'A'].include?(value)
			value = case value
				when 'J' then 'jack'
				when 'Q' then 'queen'
				when 'K' then 'king'
				when 'A' then 'ace'
			end
		end
		"<img src='/images/cards/#{suit}_#{value}.jpg' class=card_image/>"
	end

	def winner!(msg)
		@show_hit_or_stay = false
		@play_again = true
		session[:player_pot]  = session[:player_pot] + session[:player_bet] 
		@winner = "<strong>Congratulations!, #{session[:player_name]} won</strong>. <p>#{msg}</p>"
	end

	def loser!(msg)
		@show_hit_or_stay = false
		@play_again = true
		session[:player_pot]  = session[:player_pot] - session[:player_bet] 
		@loser = "<strong>Sorry!, #{session[:player_name]} lost </strong>. <p>#{msg}</p>"
	end

	def tie!(msg)
		@show_hit_or_stay = false
		@play_again = true
		@winner = "<strong>Congratulations!, it's a tie </strong>. <p>#{msg}</p>"
	end
end

before do
	@show_hit_or_stay = true
end

get '/' do
	if session[:player_name]
		redirect '/game'
	else
		redirect '/new_player'
	end
end

get '/new_player' do
	session[:player_pot] = 500
	erb :new_player
end

post '/new_player' do
	if params[:player_name].empty?
		@error = "Player Name is required"
		halt erb(:new_player)
	end
  session[:player_name] = params[:player_name]
  redirect '/bet'
end

get '/bet' do
	params[:bet_amount] = nil
	erb :bet
end

post '/bet' do
  if params[:bet_amount].nil? || params[:bet_amount].to_i == 0
  	@error = "Bet amount is required to continue with the game"
  	halt erb(:bet)
  elsif params[:bet_amount].to_i > session[:player_pot]
  	@error = "Bet amount should exceed the current pot amount ($#{session[:player_pot]})"
  	halt erb(:bet) 
  else
  	session[:player_bet] = params[:bet_amount].to_i
  	redirect '/game'
  end
  	
end

get '/game' do
	session[:turn] = session[:player_name]
	suits = ['H', 'D', 'S', 'C']
	values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
	session[:deck] = suits.product(values).shuffle!

	session[:dealer_cards] = []
	session[:player_cards] = []
	session[:dealer_cards] << session[:deck].pop
	session[:player_cards] << session[:deck].pop
	session[:dealer_cards] << session[:deck].pop
	session[:player_cards] << session[:deck].pop

	erb :game
end

post '/game/player/hit' do
	session[:player_cards] << session[:deck].pop
	player_total = calculate_total(session[:player_cards])
	if player_total == BLACKJACK_AMOUNT
		@success = winner!("#{session[:player_name]} hit a Blackjack")
	elsif player_total > BLACKJACK_AMOUNT
		@error = loser!("#{session[:player_name]} busted at #{player_total}")
	end
	erb :game, layout: false
end

post '/game/player/stay' do
	@success = "You decided to Stay!"
	redirect '/game/dealer'
end

get '/game/dealer' do
	session[:turn] = "dealer"

	dealer_total = calculate_total(session[:dealer_cards])

	if dealer_total == BLACKJACK_AMOUNT
		@error = loser!("Dealer hit a Blackjack")
	elsif dealer_total > BLACKJACK_AMOUNT
		@success = winner!("Dealer busted at #{dealer_total}")
	elsif dealer_total > DEALER_MIN_HIT
		#dealer stays
		redirect '/game/compare'
	else
		#dealer hits
		@dealer_hit_button = true
	end
	erb :game, layout: false
end

post '/game/dealer/hit' do
	session[:dealer_cards] << session[:deck].pop
	redirect '/game/dealer'
end

get '/game/compare' do
	player_total = calculate_total(session[:player_cards])
	dealer_total = calculate_total(session[:dealer_cards])
	if player_total > dealer_total
		@success = winner!("#{session[:player_name]} stayed at #{player_total}, and the dealer stayed at #{dealer_total}")
	elsif dealer_total < dealer_total
		@error = loser!("#{session[:player_name]} stayed at #{player_total}, and the dealer stayed at #{dealer_total}")
	else 
		@success = tie!("Both #{session[:player_name]} and dealer stayed at #{player_total}")
	end
	erb :game, layout: false
end

get '/game_over' do
  erb :game_over
end



