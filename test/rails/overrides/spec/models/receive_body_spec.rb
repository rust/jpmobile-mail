# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + '/../spec_helper'

describe ReceiveBody, "receiving" do
  describe "au からのメールを受信するとき" do
    describe "実機からのメールの場合2" do
      before(:each) do
        @email = open(Rails.root + "spec/fixtures/mobile_mailer/au-emoji5.eml").read
      end

      it "漢字コードを適切に変換できること" do
        body = ReceiveBody.receive(@email)

        body.should match(/テスト本文&#xea98;/)
      end
    end
  end
end
