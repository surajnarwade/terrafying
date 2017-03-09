require 'aws-sdk'

Aws.use_bundled_cert!

module Terrafying
  module Aws
    class Ops
      def initialize
        ::Aws.config.update({
          region: 'eu-west-1'
        })
        @ec2_resource = ::Aws::EC2::Resource.new
        @ec2_client = ::Aws::EC2::Client.new
      end

      def security_group(name)
        @security_groups ||= {}
        @security_groups[name] ||=
          begin
            STDERR.puts "Looking up id of security group '#{name}'"
            groups = @ec2_resource.security_groups(
              {
                filters: [
                  {
                    name: "group-name",
                    values: [name],
                  },
                ],
              }).limit(2)
            case
            when groups.count == 1
              groups.first.id
            when groups.count < 1
              raise "No security group with name '#{name}' was found."
            when groups.count > 1
              raise "More than one security group with name '#{name}' found: " + groups.join(', ')
            end
          end
      end

      def instance_profile(name)
        @instance_profiles ||= {}
        @instance_profiles[name] ||=
          begin
            resource = ::Aws::IAM::Resource.new
            STDERR.puts "Looking up id of instance profile '#{name}'"
            # unfortunately amazon don't let us filter for profiles using
            # a name filter, for now we have enumerate and filter manually
            coll = resource.instance_profiles
            profiles = []
            profiles = coll.select {|p| p.instance_profile_name =~ /#{name}/}

            case
            when profiles.count == 1
              profiles.first.instance_profile_id
            when profiles.count < 1
              raise "No instance profile with name '#{name}' was found."
            when profiles.count > 1
              raise "More than one instance profile with name '#{name}' found: " + profiles.join(', ')
            end
          end
      end

      def security_groups(*names)
        names.map{|n| security_group(n)}
      end

      def subnet(name)
        @subnets ||= {}
        @subnets[name] ||=
          begin
            STDERR.puts "Looking up id of subnet '#{name}'"
            subnets = @ec2_resource.subnets(
              {
                filters: [
                  {
                    name: "tag:Name",
                    values: [name],
                  },
                ],
              }).limit(2)
            case
            when subnets.count == 1
              subnets.first.id
            when subnets.count < 1
              raise "No subnet with name '#{name}' was found."
            when subnets.count > 1
              raise "More than one subnet with this name '#{name}' found : " + subnets.join(', ')
            end
          end
      end

      def subnets(*names)
        names.map{|n| subnet(n)}
      end

      def ami(name, owners=["self"])
        @ami ||= {}
        @ami[name] ||=
          begin
            STDERR.puts "looking for an image with prefix '#{name}'"
            resp = @ec2_client.describe_images({owners: owners})
            if resp.images.count < 1
              raise "no images were found"
            end
            m = resp.images.select { |a| /^#{name}/.match(a.name) }
            if m.count == 0
              raise "no image with name '#{name}' was found"
            end
            m.sort { |x,y| y.creation_date <=> x.creation_date }.shift.image_id
          end
      end

      def availability_zones
        @availability_zones ||=
          begin
            STDERR.puts "looking for AZs in the current region"
            resp = @ec2_client.describe_availability_zones({})
            resp.availability_zones.map { |zone|
              zone.zone_name
            }
          end
      end

      def vpc(name)
        @vpcs ||= {}
        @vpcs[name] ||=
          begin
            STDERR.puts "looking for a VPC with name '#{name}'"
            resp = @ec2_client.describe_vpcs({})
            matching_vpcs = resp.vpcs.select { |vpc|
              name_tag = vpc.tags.select { |tag| tag.key == "Name" }.first
              name_tag && name_tag.value == name
            }
            case
            when matching_vpcs.count == 1
              matching_vpcs.first.vpc_id
            when matching_vpcs.count < 1
              raise "No VPC with name '#{name}' was found."
            when matching_vpcs.count > 1
              raise "More than one VPC with name '#{name}' was found: " + matching_vpcs.join(', ')
            end
          end
      end

      def route_table(name)
        @route_tables ||= {}
        @route_tables[name] ||=
          begin
            STDERR.puts "looking for a route table with name '#{name}'"
            route_tables = @ec2_client.describe_route_tables(
              {
                filters: [
                  {
                    name: "tag:Name",
                    values: [name],
                  },
                ],
              }
            ).route_tables
            case
            when route_tables.count == 1
              route_tables.first.route_table_id
            when route_tables.count < 1
              raise "No route table with name '#{name}' was found."
            when route_tables.count > 1
              raise "More than one route table with name '#{name}' was found: " + route_tables.join(', ')
            end
          end
      end
    end

    def aws
      @@ops ||= Ops.new
    end

  end
end
