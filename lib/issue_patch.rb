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
      #before_save :check_identifier
      before_validation :check_identifier
      after_save :check_chapter
    end

  end
  
  module ClassMethods
  end
  
  module InstanceMethods
    @@cfprjcount = ProjectCustomField.find_by_name('IssCounter')    
    @@cfprjprefix = ProjectCustomField.find_by_name('IssPrefix')  
    @@cfisschapter = IssueCustomField.find_by_name('IssChapter')  

    def check_identifier
      # AUTO SUBJECT
      if self.subject == "" or self.subject == nil then
        if @@cfprjcount != nil then
          cfprjcount = self.project.custom_values.find_by_custom_field_id(@@cfprjcount.id)
          if cfprjcount != nil then
            if @@cfprjprefix != nil then
              cfprjprefix = self.project.custom_values.find_by_custom_field_id(@@cfprjprefix.id)
              if cfprjprefix != nil then
                self.subject = cfprjprefix.value+"-"+format('%04d', cfprjcount.value)
                cfprjcount.value = (cfprjcount.value.to_i+1)
                cfprjcount.save
              end
            end
          end
        end
      end

      return true 
    end

    def check_chapter
      # AUTO CHAPTER
      if @@cfisschapter != nil then
        cfisschapter = self.custom_values.find_by_custom_field_id(@@cfisschapter.id)
        if cfisschapter == nil then
          cfisschapter = CustomValue.new
          cfisschapter.custom_field = @@cfisschapter
          cfisschapter.customized = self
          cfisschapter.value = nil
        end
        if cfisschapter.value == "" or cfisschapter.value == nil then
          if self.parent != nil then
            cfparentiffchapter = self.parent.custom_values.find_by_custom_field_id(@@cfisschapter.id)
            if cfparentiffchapter == nil then
              self.parent.save
            end
            cfisschapter.value = cfparentiffchapter.value+"z."
          else
            if @@cfprjprefix != nil then
              cfprjprefix = self.project.custom_values.find_by_custom_field_id(@@cfprjprefix.id)
            end
            cfisschapter.value = cfprjprefix.value+"-z.1."
          end
          cfisschapter.save
        end
      end
      return true 
    end
  end    
end
# Add module to Issue
Issue.send(:include, IssuePatch)


