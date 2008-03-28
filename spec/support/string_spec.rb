require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

describe DataMapper::Support::String do
  
  it "should translate" do
    "%s is great!".t('DataMapper').should eql("DataMapper is great!")
  end

  it "should return a class if its content is indeed a class name"
end
