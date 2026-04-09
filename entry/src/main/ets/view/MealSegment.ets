import { AppColors, AppDimens, MEAL_LABELS } from '../common/Constants'

@Component
export struct MealSegment {
  @Prop title: string = ''
  @Prop selectedIndex: number = -1
  @State private animatingIndex: number = -1
  onSelect: (index: number | null) => void = () => {}

  private handleSelect(index: number) {
    this.animatingIndex = index
    setTimeout(() => {
      this.animatingIndex = -1
    }, 150)

    if (this.selectedIndex === index) {
      this.onSelect(null)
    } else {
      this.onSelect(index)
    }
  }

  build() {
    Column({ space: 10 }) {
      Text(this.title)
        .fontSize(15)
        .fontColor(AppColors.TEXT_SECONDARY)
        .fontWeight(FontWeight.Medium)

      Row({ space: 0 }) {
        ForEach(MEAL_LABELS, (label: string, index: number) => {
          Stack({ alignContent: Alignment.Center }) {
            // Animated background
            Row()
              .width('100%')
              .height('100%')
              .backgroundColor(this.selectedIndex === index ? AppColors.ACCENT : 'transparent')
              .borderRadius(AppDimens.RADIUS_MD)

            // Label text
            Text(label)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.selectedIndex === index ? '#FFFFFF' : AppColors.TEXT_PRIMARY)
          }
          .layoutWeight(1)
          .height(38)
          .backgroundColor(this.selectedIndex === index ? AppColors.ACCENT : 'transparent')
          .borderRadius(AppDimens.RADIUS_MD)
          .scale({
            x: this.animatingIndex === index ? 0.95 : 1,
            y: this.animatingIndex === index ? 0.95 : 1
          })
          .animation({
            duration: 200,
            curve: Curve.EaseInOut
          })
          .onClick(() => {
            this.handleSelect(index)
          })
        })
      }
      .width('100%')
      .backgroundColor(AppColors.ACCENT_LIGHT)
      .borderRadius(AppDimens.RADIUS_MD)
      .padding(3)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
