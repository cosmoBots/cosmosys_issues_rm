require_dependency 'issue'

# Patches Redmine's Issues dynamically.  Adds a relationship 
# Issue +belongs_to+ to Deliverable
module IssuePatch
  def self.included(base) # :nodoc:
    base.extend(ClassMethods)

    base.send(:include, InstanceMethods)

    # Same as typing in the class 
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development
      before_save :check_identifier
      before_validation :check_identifier
    end

  end
  
  module ClassMethods
  end
  
  module InstanceMethods
    @@cfprisscount = ProjectCustomField.find_by_name('IssCounter')    
    @@cfprissprefix = ProjectCustomField.find_by_name('IssPrefix')    

    # Wraps the association to get the Deliverable subject.  Needed for the 
    # Query and filtering
    def check_identifier
      if self.subject == "" or self.subject == nil then
        if @@cfprisscount != nil then
          cfprisscount = self.project.custom_values.find_by_custom_field_id(@@cfprisscount.id)
          if cfprisscount != nil then
            if @@cfprissprefix != nil then
              cfprissprefix = self.project.custom_values.find_by_custom_field_id(@@cfprissprefix.id)
              if cfprissprefix != nil then
                self.subject = cfprissprefix.value+"-"+format('%04d', cfprisscount.value)
                cfprisscount.value = (cfprisscount.value.to_i+1)
                cfprisscount.save
              end
            end
          end
        end
      end
      return true 
    end
  end    
end

# Add module to Issue
Issue.send(:include, IssuePatch)


