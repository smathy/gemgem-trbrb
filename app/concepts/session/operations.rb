module Session
  class SignIn < Trailblazer::Operation
    contract do
      undef :persisted? # TODO: allow with trailblazer/reform.
      attr_reader :user

      property :email,    virtual: true
      property :password, virtual: true

      validates :email, :password, presence: true
      validate :password_ok?

    private
      def password_ok?
        return unless email
        return unless password # TODO: test me.

        @user = User.find_by_email(email)
# raise @user.inspect
        return errors.add(:password, "Wrong password.") unless @user # TODO: test me.

        # DISCUSS: move validation of PW to Op#process?
        errors.add(:password, "Wrong password.") unless Monban.config.authentication_service.new(@user, password).perform
      end
    end

    def process(params)
      # model = User.find_by_email(email) 00000> pass user into form?
      validate(params[:session], nil) do |contract|
        # Monban.config.sign_in_service.new(contract.user).perform
        @model = contract.user
      end
    end
  end

  class Signout < Trailblazer::Operation
    def process(params)
      # empty for now, this could e.g. log signout, etc.
    end
  end


  require "reform/form/validation/unique_validator.rb"
  class SignUp < Trailblazer::Operation # Tyrant::SignUp.
    include CRUD
    model User, :create

    contract do
      property :email
      property :password, virtual: true
      property :confirm_password, virtual: true
      property :password_digest#, deserializer: { writeable: false }

      validates :email, :password, :confirm_password, presence: true
      validates :email, email: true, unique: true
      validate :password_ok?

    private
      # TODO: more, like minimum 6 chars, etc.
      def password_ok?
        return unless email and password
        errors.add(:password, "Passwords don't match") if password != confirm_password
      end
    end


    # sucessful signup:
    # * hash password, set confirmed
    # * hash password, set unconfirmed with token etc.

    # * no password, unconfirmed, needs password.
    def process(params)
      validate(params[:user]) do |contract|
        # form.email, form.password
        #or password
        contract.password_digest = Monban.hash_token(contract.password)
        contract.save# do |hash|
          # Monban.config.sign_up_service.new(email: "foo@example.com", password: "password").perform
          #Monban.config.sign_up_service.new(hash).perform
        # end
      end
    end


    # class UnconfirmedNoPassword < Trailblazer::Operation
    #   include CRUD
    #   model User, :create

    #   contract do
    #     property :email
    #     validates :email, email: true, unique: true, presence: true
    #   end

    #   def process(params)
    #     # TODO: i want the user here!
    #     validate(params[:user]) do |contract|
    #       model.auth_meta_data = {confirmation_token: "asdfasdfasfasfasdfasdf", confirmation_created_at: "assddsf"}
    #       contract.save
    #     end
    #   end
    # end

    class UnconfirmedNoPassword < Trailblazer::Operation
      contract do
        property :email
        validates :email, email: true#, unique: true, presence: true
      end

      def process(params)
        # @contract = contract_for(nil, params[:user])
        # if @contract.validate({}) # DISCUSS: do we need that?
          params[:user].auth_meta_data = {confirmation_token: "asdfasdfasfasfasdfasdf", confirmation_created_at: "assddsf"}
        #   @contract.save
        #   return
        # end
        # return invalid!

        # # TODO: i want the user here!
        # validate(params[:user]) do |contract|
        #   model.auth_meta_data = {confirmation_token: "asdfasdfasfasfasdfasdf", confirmation_created_at: "assddsf"}
        #   contract.save
        # end
      end
    end
  end
end