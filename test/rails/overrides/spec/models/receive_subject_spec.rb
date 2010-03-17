# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + '/../spec_helper'

describe ReceiveSubject, "receiving" do
  describe "au からのメールを受信するとき" do
    describe "実機からのメールの場合2" do
      before(:each) do
        @email = open(Rails.root + "spec/fixtures/mobile_mailer/au-emoji5.eml").read
      end

      it "漢字コードを適切に変換できること" do
        subject = ReceiveSubject.receive(@email)

        subject.should == "テスト&#xeaa7;OKよー"
      end
    end
  end
end
