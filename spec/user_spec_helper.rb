module UserSpecHelper
  def user( hash={} )
    u = OpenStruct.new( hash.merge( :save => true ) )
    u.class_eval { include NetflixDogs::NetflixUserValidations }
    u 
  end 
end  