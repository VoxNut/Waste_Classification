import 'package:waste_classification/data/models/waste_category.dart';

abstract final class WasteCategories {
  static const organic = WasteCategory(
    id: 'organic',
    nameVi: 'Rác hữu cơ',
    nameEn: 'Organic waste',
    descriptionVi:
        'Rác có nguồn gốc từ thực phẩm hoặc cây cối, có khả năng phân hủy tự nhiên.',
    descriptionEn: 'Waste from food or plants that can break down naturally.',
    disposalInstructionVi:
        'Loại bỏ túi nilon và vật liệu lẫn tạp. Cho vào thùng rác hữu cơ hoặc khu vực ủ phân nếu có.',
    disposalInstructionEn:
        'Remove plastic bags and contaminants. Put it in the organic bin or composting area when available.',
    colorHex: '#A9D8B4',
    iconAsset: 'assets/icons/organic.svg',
  );

  static const recyclable = WasteCategory(
    id: 'recyclable',
    nameVi: 'Rác tái chế',
    nameEn: 'Recyclable waste',
    descriptionVi:
        'Vật liệu có thể được thu gom và xử lý để tạo thành sản phẩm mới.',
    descriptionEn:
        'Materials that can be collected and processed into new products.',
    disposalInstructionVi:
        'Làm sạch phần thức ăn hoặc chất lỏng còn lại, để khô và cho vào thùng rác tái chế.',
    disposalInstructionEn:
        'Rinse away food or liquid residue, let it dry, and place it in the recycling bin.',
    colorHex: '#F2DDA4',
    iconAsset: 'assets/icons/recyclable.svg',
  );

  static const other = WasteCategory(
    id: 'other',
    nameVi: 'Rác vô cơ / khác',
    nameEn: 'Other waste',
    descriptionVi:
        'Rác khó phân hủy hoặc chưa phù hợp với luồng tái chế thông thường.',
    descriptionEn:
        'Waste that does not decompose easily or fit common recycling streams.',
    disposalInstructionVi:
        'Cho vào thùng rác còn lại. Với pin, hóa chất hoặc thiết bị điện tử, hãy chuyển đến điểm thu gom chuyên biệt.',
    disposalInstructionEn:
        'Place it in the general waste bin. Take batteries, chemicals, or electronics to a dedicated collection point.',
    colorHex: '#D6D9D5',
    iconAsset: 'assets/icons/other.svg',
  );

  static const all = [organic, recyclable, other];

  static WasteCategory byId(String id) =>
      all.firstWhere((category) => category.id == id, orElse: () => other);
}
