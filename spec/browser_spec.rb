require 'watirspec_helper'

describe Watir::Browser do

  describe "#execute_script" do
    before { browser.goto WatirSpec.url_for("definition_lists.html") }

    it "wraps elements as Watir objects" do
      returned = browser.execute_script("return document.body")
      expect(returned).to be_kind_of(Watir::Body)
    end

    it "wraps elements in an array" do
      list = browser.execute_script("return [document.body];")
      expect(list.size).to eq 1
      expect(list.first).to be_kind_of(Watir::Body)
    end

    it "wraps elements in a Hash" do
      hash = browser.execute_script("return {element: document.body};")
      expect(hash['element']).to be_kind_of(Watir::Body)
    end

    it "wraps elements in a deep object" do
      hash = browser.execute_script("return {elements: [document.body], body: {element: document.body }}")

      expect(hash['elements'].first).to be_kind_of(Watir::Body)
      expect(hash['body']['element']).to be_kind_of(Watir::Body)
    end
  end

  describe "#send_key{,s}" do
    it "sends keystrokes to the active element" do
      browser.goto WatirSpec.url_for "forms_with_input_elements.html"

      browser.send_keys "hello"
      expect(browser.text_field(id: "new_user_first_name").value).to eq "hello"
    end

    it "sends keys to a frame" do
      browser.goto WatirSpec.url_for "frames.html"
      tf = browser.frame.text_field(id: "senderElement")
      tf.clear

      browser.frame.send_keys "hello"

      expect(tf.value).to eq "hello"
    end
  end

  it "raises an error when trying to interact with a closed browser" do
    browser.goto WatirSpec.url_for "definition_lists.html"
    browser.close

    expect { browser.dl(id: "experience-list").id }.to raise_error(Watir::Exception::Error, "browser was closed")
    $browser = WatirSpec.new_browser
  end

  describe "#wait_while" do
    it "delegates to the Wait module" do
      expect(Watir::Wait).to receive(:while).with(timeout: 3, message: "foo", interval: 0.2, object: browser).and_yield

      called = false
      browser.wait_while(timeout: 3, message: "foo", interval: 0.2) { called = true }

      expect(called).to be true
    end
  end

  describe "#wait_until" do
    it "delegates to the Wait module" do
      expect(Watir::Wait).to receive(:until).with(timeout: 3, message: "foo", interval: 0.2, object: browser).and_yield

      called = false
      browser.wait_until(timeout: 3, message: "foo", interval: 0.2) { called = true }

      expect(called).to be true
    end
  end

  describe "#wait" do
    it "waits until document.readyState == 'complete'" do
      expect(browser).to receive(:ready_state).and_return('incomplete')
      expect(browser).to receive(:ready_state).and_return('complete')

      browser.wait
    end
  end

  describe "#ready_state" do
    it "gets the document's readyState property" do
      expect(browser).to receive(:execute_script).with('return document.readyState')
      browser.ready_state
    end
  end

  describe "#inspect" do
    it "works even if browser is closed" do
      expect(browser).to receive(:url).and_raise(Errno::ECONNREFUSED)
      expect { browser.inspect }.to_not raise_error
    end
  end

  describe '#screenshot' do
    it 'returns an instance of of Watir::Screenshot' do
      expect(browser.screenshot).to be_kind_of(Watir::Screenshot)
    end
  end
end
