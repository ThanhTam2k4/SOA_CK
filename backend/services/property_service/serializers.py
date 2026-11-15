from rest_framework import serializers
from .models import MaintenanceRequest, Property, Room


class RoomSerializer(serializers.ModelSerializer):
    property_name = serializers.CharField(source='property.name', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = Room
        fields = [
            'id',
            'property',
            'property_name',
            'room_number',
            'floor',
            'area',
            'rent_price',
            'deposit_amount',
            'max_occupants',
            'current_occupants',
            'status',
            'status_display',
            'amenities',
            'description',
            'initial_electric_reading',
            'initial_water_reading',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def validate(self, attrs):
        max_occ = attrs.get('max_occupants', getattr(self.instance, 'max_occupants', 2))
        current = attrs.get('current_occupants', getattr(self.instance, 'current_occupants', 0))
        if current > max_occ:
            raise serializers.ValidationError(
                {'current_occupants': f'Số người đang ở ({current}) vượt quá tối đa ({max_occ}).'})
        return attrs


class PropertySerializer(serializers.ModelSerializer):
    full_address = serializers.CharField(read_only=True)
    total_rooms_count = serializers.IntegerField(read_only=True)
    available_rooms_count = serializers.IntegerField(read_only=True)
    occupied_rooms_count = serializers.IntegerField(read_only=True)
    rooms = RoomSerializer(many=True, read_only=True)

    class Meta:
        model = Property
        fields = [
            'id',
            'owner_id',
            'name',
            'address',
            'ward',
            'district',
            'city',
            'full_address',
            'total_floors',
            'electricity_rate',
            'water_rate',
            'internet_rate',
            'description',
            'rules',
            'image_url',
            'total_rooms_count',
            'available_rooms_count',
            'occupied_rooms_count',
            'rooms',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'owner_id', 'created_at', 'updated_at']

    def create(self, validated_data):
        # Tự động gán owner_id từ claim user_id của JWT (Identity Service)
        request = self.context.get('request')
        if request and hasattr(request, 'user') and request.user.is_authenticated:
            validated_data['owner_id'] = int(request.user.id)
        return super().create(validated_data)


class MaintenanceRequestSerializer(serializers.ModelSerializer):
    room_number = serializers.CharField(source='room.room_number', read_only=True)
    property_id = serializers.IntegerField(source='room.property_id', read_only=True)
    property_name = serializers.CharField(source='room.property.name', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    priority_display = serializers.CharField(source='get_priority_display', read_only=True)
    mark_room_maintenance = serializers.BooleanField(
        write_only=True, required=False, default=False,
        help_text='Nếu true: chuyển phòng sang trạng thái MAINTENANCE trong lúc xử lý.')

    class Meta:
        model = MaintenanceRequest
        fields = [
            'id', 'room', 'room_number', 'property_id', 'property_name',
            'title', 'description', 'priority', 'priority_display',
            'status', 'status_display', 'reported_by_id', 'assigned_to', 'cost',
            'resolution_note', 'mark_room_maintenance',
            'started_at', 'completed_at', 'created_at', 'updated_at',
        ]
        # Trạng thái chỉ thay đổi qua các action start/complete/cancel.
        read_only_fields = ['id', 'status', 'reported_by_id', 'started_at', 'completed_at',
                            'created_at', 'updated_at']
