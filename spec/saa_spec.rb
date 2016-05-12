require 'spec_helper'
require 'net/http'
require 'test_validation'

# Test abandonment modal in all steps
# Allows specifying mode where it just opens the modal
def test_abandon_modal(step_no, saa, just_open = false)
	wait = Selenium::WebDriver::Wait.new(timeout: 3)
	$logger.info("Step " + step_no.to_s + " abandonment modal")
	#Make sure abandonment modal appears/closes correctly for each link
	if !just_open
		links = [saa.logo_link, saa.back_to_home_link, saa.privacy_policy_link, saa.terms_of_use_link, saa.site_map_link, saa.office_listings_link]
		links.each do |link|
			wait.until { link.displayed? }
			link.click
			wait.until { saa.abandonment_modal.displayed? }

			wait.until { saa.close_abandon_modal.displayed? }
			saa.close_abandon_modal.click
			# Wait for modal to disappaer
			wait_for_disappear(saa.abandonment_modal, 3)
		end
	else
		wait.until { saa.logo_link.displayed? }
		saa.logo_link.click
		wait.until { saa.abandonment_modal.displayed? }
	end
end

#Get through step 1 with no testing (e.g. to get to step 2)
#Includes navigating to SAA page
def step_1(continue = true)
	wait = Selenium::WebDriver::Wait.new(timeout: 3)
	saa = SaaPage.new()
	header = HeaderPage.new()
	parsed = JSON.parse(open("spec/page_titles.json").read)

	header.saa_cta.click
	if(ENV['BROWSER_TYPE'] == 'IE')
		sleep 1
	end
	wait.until { $test_driver.title.include? parsed["top-pages"]["SAA"] }
	if continue
		wait.until { saa.yes_cta.displayed? }
		saa.yes_cta.click
	end
end

#Get through step 2
#Includes clicking "next step" CTA, unless specified
def step_2(continue = true)
	wait = Selenium::WebDriver::Wait.new(timeout: 3)
	saa = SaaPage.new()
	#Click 'no' under "Has this patient had an exam with us in the past?"
	wait.until { saa.past_exam_no.displayed? }
	saa.past_exam_no.click

	#Click "18 or older" under "How old is the patient?"
	wait.until { saa.how_old_over_18.displayed? }
	saa.how_old_over_18.click

	# Click on "Select primary reason" and choose an item
	wait.until { saa.primary_reason_dropdown.displayed? }
	js_scroll_up(saa.primary_reason_dropdown)
	saa.primary_reason_dropdown.click

	wait.until { saa.primary_reason_item(2).displayed? }
	js_scroll_up(saa.primary_reason_item,true)
	saa.primary_reason_item(2).click

	#Click on "Next Step" CTA
	if continue
		wait.until { saa.next_step.displayed? }
		saa.next_step.click
		#Allow accordion menu to open
		sleep 1
	end
end

#Get through step 3
#DOES NOT submit the form
def step_3()
	wait = Selenium::WebDriver::Wait.new(timeout: 3)
	saa = SaaPage.new()
	wait_longer = Selenium::WebDriver::Wait.new(timeout: 30)
	test_val = TestValidation.new()

	#First name
	test_val.text_valid_input(saa.first_name,('a'..'z').to_a.shuffle[0,8].join + "'",true,saa.last_name)

	#Last name
	test_val.text_valid_input(saa.last_name, ('a'..'z').to_a.shuffle[0,8].join + "-" + ('a'..'z').to_a.shuffle[0,8].join, true, saa.first_name)

	#Email
	test_val.text_valid_input(saa.email, ('a'..'z').to_a.shuffle[0,8].join + "@topnotchltd.com", true, saa.first_name)

	#Month
	test_val.text_valid_input(saa.dob_month, rand(1 .. 12), true, saa.first_name)

	#Day
	test_val.text_valid_input(saa.dob_day, rand(1 .. 31), true, saa.first_name)

	#Year
	test_val.text_valid_input(saa.dob_year, "1975", true, saa.first_name)

	#Phone number
	#Area code
	test_val.text_valid_input(saa.pn_area_code, 666, true, saa.email)

	#Exchange code
	test_val.text_valid_input(saa.pn_exchange_code, 666, true, saa.email)

	#Suffix code
	test_val.text_valid_input(saa.pn_suffix_code, "666666", true, saa.email)

	#Click on 'yes' under "Does the patient have dental insurance?"
	wait.until { saa.insurance_yes.displayed? }
	saa.insurance_yes.click

	#Wait for calander to propogate
	wait_longer.until { saa.apt_time_header.displayed? }
end

describe "'Schedule An Appointment' page functionality" do
	header = HeaderPage.new()
	saa = SaaPage.new()
	scroll_sleep_time = 3
	wait = Selenium::WebDriver::Wait.new(timeout: 3)
	wait_longer = Selenium::WebDriver::Wait.new(timeout: 15)
	test_val = TestValidation.new()
	parsed = JSON.parse(open("spec/page_titles.json").read)
	title = parsed["top-pages"]["SAA"]

	describe " - User can schedule an appointment correctly" do
		$logger.info("User can schedule an appointment correctly")

		it " - Step 1" do
			$logger.info("Step 1")
			#Click SAA link
			header.saa_cta.click
			wait.until { $test_driver.title.include? title }

			#Make sure we are at default office
			wait.until { saa.location_name.displayed? }
			expect(saa.location_name.attribute("innerHTML") == "Cicero, NY")

			#Make sure office was geolocated
			expect(saa.show_location.attribute("innerHTML").include? "We've determined that this is the closest Aspen Dental office to your location.")

			#Check FAO link
			test_link_back(saa.fao_link, title, parsed["top-pages"]["FAO"])
		end

		it " - Step 1 non-geolocated office" do 
			$logger.info("Step 1 non-geolocated office")

			#Manually navigate to office page
			$test_driver.navigate.to("https://" + $ad_env + $domain + "/dentist/prescott-valley-az-86314-2278")

			#Click SAA link
			header.saa_cta.click
			wait.until { $test_driver.title.include? title }
			sleep 1

			#Make sure we are at the office we specified
			wait.until { saa.location_name.displayed? }
			expect(saa.location_name.attribute("innerHTML") == "Prescott Valley, AZ")

			#Make sure office was NOT geolocated
			expect(saa.show_location.attribute("innerHTML").include? "Do you want to schedule a new patient appointment at the following location:")
		end

		it " - Step 2" do
			$logger.info("Step 2")

			step_1()

			#Click 'yes' under "Has this patient had an exam with us in the past?"; check for disclaimer
			wait.until { saa.past_exam_yes.displayed? }
			saa.past_exam_yes.click
			wait.until { saa.past_exam_disclaimer.displayed? }

			#Click 'no' under "Has this patient had an exam with us in the past?"
			wait.until { saa.past_exam_no.displayed? }
			saa.past_exam_no.click

			#Click "Under 18" under "How old is the patient?"; check for disclaimer
			wait.until { saa.how_old_under_18.displayed? }
			saa.how_old_under_18.click
			wait.until { saa.age_disclaimer.displayed? }

			#Click "18 or older" under "How old is the patient?"
			wait.until { saa.how_old_over_18.displayed? }
			saa.how_old_over_18.click

			# Make sure we can't go to next step without picking a reason
			wait.until { saa.next_step.displayed? }
			saa.next_step.click
			wait.until { saa.reason_error.displayed? }

			# Click on "Select primary reason" and choose first item
			wait.until { saa.primary_reason_dropdown.displayed? }
			saa.primary_reason_dropdown.click

			item = saa.primary_reason_item
			wait.until { item.displayed? }
			js_scroll_up(saa.primary_reason_item)
			item.click
		end

		it " - Step 2 'why do we ask' boxes" do 
			$logger.info("Step 2 'why do we ask' boxes")

			step_1()
			step_2(false) 

			#Click 'Why do we ask' links and make sure shadowboxes appear; do it in reverse order
			wait.until { saa.iae_why_link.displayed? }
			js_scroll_up(saa.iae_why_link,true)
			saa.iae_why_link.click
			wait.until { saa.iae_why_box.displayed? }

			wait.until { saa.isp_why_link.displayed? }
			js_scroll_up(saa.isp_why_link,true)
			saa.isp_why_link.click
			wait.until { saa.isp_why_box.displayed? }

			wait.until { saa.np_why_link.displayed? }
			js_scroll_up(saa.np_why_link,true)
			saa.np_why_link.click
			wait.until { saa.np_why_box.displayed? }
		end

		it " - Step 3 calander" do 
			$logger.info("Step 3 calander")

			step_1()
			step_2()

			#Click all the active dates/times on the calendar
			wait_longer.until { saa.apt_time_header.displayed? }
			$logger.info("Step 3 calander dates/times")
			for r in 1 .. 5
				for c in 1 .. 7
					if saa.calendar_item(r,c).attribute("class").include? "is-active"
						#Click link until it's highlighted or we reach a limit
						start_time = time_now_sec
						while !saa.calendar_item(r,c).attribute("class").include? "ui-datepicker-current-day" do
							js_scroll_up(saa.calendar_item(r,c))
							saa.calendar_item(r,c).click
							if time_now_sec >= start_time + scroll_sleep_time
								fail("Calendar item row: "+ r +" column: "+ c +" did not highlight")
							end
						end
						wait_longer.until { saa.apt_time_header.displayed? }

						#Click all the active times
						saa.times.each do |elem|
							js_scroll_up(elem)
							elem.click
							link = $test_driver.find_element(:link_text, elem.text)
							wait.until { link.displayed? }
							expect(link.attribute("class").include? "is-selected").to eql true
						end
					end
				end
			end #End of loops

		end

		it " - Step 3 validation - First/last name" do
			$logger.info("Step 3 validation - First/last name, email")

			step_1()
			step_2()

			test_val.text_invalid_input(saa.first_name, "1235!@#{}", true, saa.last_name)
			test_val.text_valid_input(saa.first_name, ('a'..'z').to_a.shuffle[0,8].join + "'", true, saa.last_name)

			test_val.text_invalid_input(saa.last_name, "1235!@#{}", true, saa.first_name)
			test_val.text_valid_input(saa.last_name, ('a'..'z').to_a.shuffle[0,8].join + "-" + ('a'..'z').to_a.shuffle[0,8].join, true, saa.first_name)

			#Check invalid input
			invalid_emails = ["a","a@a","a@a.a"]
			for i in 0 .. invalid_emails.length-1
				test_val.text_invalid_input(saa.email, invalid_emails[i], true, saa.first_name)
			end
			test_val.text_valid_input(saa.email, ('a'..'z').to_a.shuffle[0,8].join + "@topnotchltd.com", true, saa.first_name)
		end

		it " - Step 3 validation - Date of birth" do
			$logger.info("Step 3 validation - Date of birth")

			step_1()
			step_2()

			#Month
			test_val.text_invalid_input(saa.dob_month, "13", true, saa.first_name)
			test_val.text_valid_input(saa.dob_month, rand(1 .. 12), true, saa.first_name)

			#Day
			test_val.text_invalid_input(saa.dob_day, "32", true, saa.first_name)
			test_val.error_msg(saa.dob_error,true)
			test_val.text_valid_input(saa.dob_day, rand(1 .. 31), true, saa.first_name)

			#Year
			start_year = Date.today.year - 99
			end_year = Date.today.year - 19

			test_val.text_invalid_input(saa.dob_year, start_year - 1, true, saa.first_name)
			test_val.error_msg(saa.dob_error,true)
			test_val.text_invalid_input(saa.dob_year, end_year + 2, true, saa.first_name)
			test_val.error_msg(saa.dob_error,true)
			#Valid
			test_val.text_valid_input(saa.dob_year, rand(start_year .. end_year), true, saa.first_name)
			begin
				test_val.error_msg(saa.dob_error,false)
			rescue Selenium::WebDriver::Error::NoSuchElementError
				#This is what we want
			end
		end

		it " - Step 3 validation - Phone number" do
			$logger.info("Step 3 validation - Phone number")

			step_1()
			step_2()

			#Area code
			test_val.text_invalid_input(saa.pn_area_code, "abc", true, saa.email)
			test_val.text_valid_input(saa.pn_area_code, rand(200 .. 999), true, saa.email)

			#Exchange code
			test_val.text_invalid_input(saa.pn_exchange_code, "abc", true, saa.email)
			test_val.text_valid_input(saa.pn_exchange_code, rand(200 .. 999), true, saa.email)

			#Suffix code
			test_val.text_invalid_input(saa.pn_suffix_code, "abcd", true, saa.email)
			test_val.text_valid_input(saa.pn_suffix_code, rand(2000 .. 9999), true, saa.email)
		end

		it " - Step 3 validation - The rest" do
			$logger.info("Step 3 validation - The rest")

			step_1()
			step_2()

			#Make sure we can't continue without selecting one
			wait.until { saa.schedule_cta.displayed? }
			saa.schedule_cta.click
			wait.until { saa.insurance_error.displayed? }
			#Click on 'yes' under "Does the patient have dental insurance?"
			saa.insurance_yes.click
			#Click on 'no' under "Does the patient have dental insurance?"
			saa.insurance_no.click

			#Click "Learn about our policy here" link
			saa.policy_link.click
			#Make sure policy message appears
			wait.until { saa.policy_message.displayed? }

			#Select "mobile phone" in the phone type dropdown
			js_scroll_up(saa.phone_type_dropdown)
			saa.phone_type_dropdown.click
			saa.phone_type_item.click
			#Make sure disclaimer shows
			wait.until { saa.mobile_phone_disclaimer.displayed? }

			saa.di_why_link.click
			wait.until { saa.di_why_box.displayed? }
		end

		# it " - Form submission and success" do
		# 	$logger.info("Form submission and success")

		# 	step_1()
		# 	step_2()
		# 	step_3()

		# 	#Submit form and check success
		# 	saa.schedule_cta.click
		# 	wait_longer.until { saa.thank_you.displayed? }
		# end

		it " - Abandonment modal" do 
			$logger.info("Abandonment modal")

			#Step 1
			step_1(false)
			sleep 1
			test_abandon_modal(1, saa)
			wait.until { saa.yes_cta.displayed? }
			saa.yes_cta.click

			#Step 2
			step_2(false)
			test_abandon_modal(2, saa)
			wait.until { saa.next_step.displayed? }
			saa.next_step.click

			#Step 3
			sleep 1
			step_3()
			test_abandon_modal(3, saa)

			#Test links on modal
			test_abandon_modal(3, saa, true)
			#Remind me later
			test_link_back(saa.remind_me_later, title, parsed["misc"]["sign-up"])
			test_abandon_modal(1, saa, true)
			#Yes I'd like to leave
			test_link_back(saa.yes_leave_link, title, parsed["top-pages"]["home"])
			test_abandon_modal(1, saa, true)
			saa.back_to_schedule_cta.click
			# Wait for modal to disappaer
			wait_for_disappear(saa.abandonment_modal, 3)
		end

		# it " - Sign up page" do
		# 	#Get page titles from json
		# 	parsed = JSON.parse(open("spec/page_titles.json").read)
		# 	forsee = ForseePage.new().add_cookies()

		# 	$logger.info("Sign up page")
		# 	step_1()
		# 	step_2()
		# 	step_3()
		# 	#Submit form and check success
		# 	wait.until { saa.schedule_cta.displayed? }
		# 	saa.schedule_cta.click
		# 	wait_longer.until { saa.thank_you.displayed? }

		# 	$logger.info("Sign up")

		# 	$logger.info("Links")
		# 	#Loop through all the links
		# 	links = [saa.print_offers_cta, saa.download_forms_cta, saa.add_calendar_link, saa.directions_link]
		# 	titles = [parsed["top-pages"]["pricing-offers"], parsed["misc"]["patient-forms"], "Calendar", "Google Maps"]
		# 	for i in 0 .. links.length-1
		# 		wait.until { links[i].displayed? }
		# 		links[i].click
		# 		$test_driver.switch_to.window( $test_driver.window_handles.last )
		# 		wait_longer.until { $test_driver.title.include? titles[i] }
		# 		if ENV['BROWSER_TYPE'] == 'IE'
		# 			$test_driver.execute_script("window.open('', '_self', ''); window.close();")
		# 		else
		# 			$test_driver.execute_script("window.close();")
		# 		end
		# 		$test_driver.switch_to.window( $test_driver.window_handles.first )
		# 		#IE likes to not close the window, so double check
		# 		if ENV['BROWSER_TYPE'] == 'IE'
		# 			sleep 3
		# 			if (test_driver.title.include? titles[i])
		# 				$test_driver.execute_script("window.open('', '_self', ''); window.close();")
		# 				$test_driver.switch_to.window( $test_driver.window_handles.first )
		# 			end
		# 		end
		# 	end
		# 	#Check 'add to outlook' link status (we don't want to download the file)
		# 	url = saa.add_outlook_link.attribute("href").split(".com/")
		# 	response = nil
		# 	Net::HTTP.start(url[0].split("https://").last + ".com", 80) {|http|
		# 		response = http.head("/" + url[1])
		# 	}
		# 	if(response.code != "200")
		# 		fail("Outlook link returned code: " + response.code)
		# 	end

		# 	$logger.info("Enter username")
		# 	wait.until { saa.username.displayed? }
		# 	#Invalid input
		# 	invalid_cases = ["12345678","!@#!@#!@","btntes7"]
		# 	for i in 0.. invalid_cases.length-1
		# 		saa.username.clear
		# 		saa.username.send_keys(invalid_cases[i])
		# 		js_scroll_up(saa.password)
		# 		saa.password.click
		# 		expect(saa.username.attribute("class").include? "is-error").to eql true
		# 	end
		# 	#Valid input
		# 	saa.username.clear
		# 	saa.username.send_keys(('a'..'z').to_a.shuffle[0,8].join)
		# 	saa.password.click
		# 	expect(saa.username.attribute("class").include? "is-error").to eql false

		# 	$logger.info("Enter password")
		# 	#Invalid input
		# 	invalid_cases = ["asdfjkl8","asdfjkl#","Bnt$s7"]
		# 	for i in 0.. invalid_cases.length-1
		# 		saa.password.clear
		# 		saa.password.send_keys(invalid_cases[i])
		# 		saa.confirm_password.click
		# 		expect(saa.password.attribute("class").include? "is-error").to eql true
		# 	end
		# 	#Different passwords
		# 	saa.password.clear
		# 	saa.password.send_keys("Bnte$s7")
		# 	saa.confirm_password.clear
		# 	saa.confirm_password.send_keys("Bnte$s8")
		# 	saa.password.click
		# 	expect(saa.confirm_password.attribute("class").include? "is-error").to eql true
		# 	#Valid input
		# 	saa.password.clear
		# 	password = "TN1" + ('a'..'z').to_a.shuffle[0,8].join + "!"
		# 	saa.password.send_keys(password)
		# 	wait.until { saa.confirm_password.displayed? }
		# 	saa.confirm_password.clear
		# 	saa.confirm_password.send_keys(password)
		# 	saa.security_answer.click
		# 	expect(saa.password.attribute("class").include? "is-error").to eql false
		# 	expect(saa.confirm_password.attribute("class").include? "is-error").to eql false

		# 	$logger.info("Security question")
		# 	#Invalid input
		# 	#No input
		# 	saa.security_answer.click
		# 	saa.confirm_password.click
		# 	expect(saa.security_answer.attribute("class").include? "is-error").to eql true
		# 	#Make sure we can't enter more than 50 characters
		# 	over_fifty = "WXka7ZXJB4vKZy4XQ7f8O19HLM6nGPz5SckBGD8Gok0nq5Wy1Q$asdf" #Dollar sign is 51st character
		# 	saa.security_answer.clear
		# 	saa.security_answer.send_keys(over_fifty)
		# 	if(saa.security_answer.attribute("value") != over_fifty.split("$").first)
		# 		fail("Security answer was not truncated to 50 characters")
		# 	end
		# 	#Valid input
		# 	wait.until { saa.security_dropdown.displayed? }
		# 	js_scroll_up(saa.security_dropdown,true)
		# 	saa.security_dropdown.click
		# 	item = rand(1 .. 6)
		# 	wait.until { saa.security_dropdown_item(item).displayed? }
		# 	saa.security_dropdown_item(item).click
		# 	saa.security_answer.send_keys(('a'..'z').to_a.shuffle[0,8].join)
		# 	expect(saa.security_answer.attribute("class").include? "is-error").to eql false

		# 	$logger.info("Checkbox")
		# 	#Make sure CTA changed from being greyed out
		# 	expect(saa.create_cta.attribute("class").include? "inactive").to eql true
		# 	saa.account_checkbox.click
		# 	expect(saa.create_cta.attribute("class").include? "inactive").to eql false

		# 	$logger.info("Create account CTA")
		# 	saa.create_cta.click

		# 	$logger.info("Success page")
		# 	wait_longer.until { saa.account_login_cta.displayed? }
		# 	#Test all the links
		# 	#$test_driver.navigate.to("https://" + $ad_env + $domain + "/my-account?guid=cdf8081eb7e24907bf6fdb2df9565a31&confirmation=1")
		# 	title = "My Account for Upcoming Dental Work"
		# 	scroll = ENV['BROWSER_TYPE'] == 'CHROME'
		# 	test_link_back(saa.sign_in_cta, title, parsed["my-account"]["sign-in"], false, 3, scroll)
		# 	sleep scroll_sleep_time
		# 	test_link_back(saa.browse_cta, title, parsed["top-pages"]["home"], false, 3, scroll)
		# 	sleep scroll_sleep_time
		# 	test_link_back(saa.account_login_cta, title, parsed["my-account"]["sign-in"], false, 3, scroll)
		# 	sleep scroll_sleep_time
		# 	test_link_back(saa.account_faq_link, title, parsed["faqs"]["my-account"], false, 3, scroll)
		# 	sleep scroll_sleep_time
		# 	test_link_back(saa.contact_link, title, parsed["about"]["contact"], false, 3, scroll)
		# end
	end
end