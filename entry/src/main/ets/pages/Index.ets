import { AppColors, AppDimens, MEAL_LABELS } from '../common/Constants'
import { TodayViewModel, ValidationResult } from '../viewmodel/TodayViewModel'
import { HeatmapViewModel, HeatmapWeek, HeatmapCell } from '../viewmodel/HeatmapViewModel'
import { TrendViewModel } from '../viewmodel/TrendViewModel'
import { DailyRecord, createEmptyRecord } from '../model/DailyRecord'
import { MealSegment } from '../view/MealSegment'
import { promptAction, Animator, AnimatorResult } from '@kit.ArkUI'
import { window } from '@kit.ArkUI'

import { vibrator } from '@kit.SensorServiceKit'

@Entry
@ComponentV2
struct Index {
  @Local currentTab: number = 0
  @Local vm: TodayViewModel | null = null
  @Local heatmapVm: HeatmapViewModel | null = null
  @Local trendVm: TrendViewModel | null = null
  @Local statusBarHeight: number = 44
  @Local randomTitle: string = ''
  private trendChartContext: CanvasRenderingContext2D = new CanvasRenderingContext2D()
  private bodyFatChartContext: CanvasRenderingContext2D = new CanvasRenderingContext2D()
  @Local private chartAnimationProgress: number = 1
  @Local private bodyFatChartAnimationProgress: number = 1
  @Local private selectedPointIndex: number = -1
  @Local private bodyFatSelectedPointIndex: number = -1
  @Local private bubbleAnimationProgress: number = 0
  @Local private bodyFatBubbleAnimationProgress: number = 0
  private chartAnimator: AnimatorResult | null = null
  private bubbleAnimator: AnimatorResult | null = null
  private bodyFatChartAnimator: AnimatorResult | null = null
  private bodyFatBubbleAnimator: AnimatorResult | null = null

  // 测试工具相关状态
  @Local testButtonVisible: boolean = false  // 按钮是否显示
  @Local showTestTools: boolean = false       // 弹窗是否显示
  private trendTabClickCount: number = 0
  @Local showDateEditDialog: boolean = false
  @Local editDateText: string = ''
  @Local editingRecord: DailyRecord | null = null
  @Local editBreakfast: number = -1
  @Local editLunch: number = -1
  @Local editDinner: number = -1
  @Local editWeightText: string = ''
  @Local editBodyFatText: string = ''

  // 热力图编辑相关状态
  @Local heatmapEditBreakfast: number = -1
  @Local heatmapEditLunch: number = -1
  @Local heatmapEditDinner: number = -1
  @Local heatmapEditWeightText: string = ''
  @Local heatmapEditBodyFatText: string = ''

  // Light vibration feedback
  private vibrateLight(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 10
      }, {
        id: 0,
        usage: 'touch'
      })
    } catch (e) {
      // Vibration not available
    }
  }

  aboutToAppear(): void {
    this.trendTabClickCount = 0
    this.testButtonVisible = false
    this.showTestTools = false
    const titles = ['今天怎么样？', '元气满满', '少吃点奥']
    this.randomTitle = titles[Math.floor(Math.random() * titles.length)]
    const context = getContext(this)
    this.vm = new TodayViewModel(context)
    this.vm.loadToday()
    this.heatmapVm = new HeatmapViewModel(context)
    this.heatmapVm.loadMonth(new Date().getFullYear(), new Date().getMonth() + 1)
    this.vm.onDataSaved = () => {
      this.heatmapVm?.loadMonth(this.heatmapVm.year, this.heatmapVm.month)
    }
    this.trendVm = new TrendViewModel(context)
    this.trendVm.onDataLoaded = () => {
      this.refreshTrendChart()
      this.refreshBodyFatChart()
    }
    this.trendVm.loadTrend('week')
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
        TabContent() {
          this.TodayPage()
        }
        .tabBar('')

        TabContent() {
          this.HeatmapPage()
        }
        .tabBar('')

        TabContent() {
          this.TrendPage()
        }
        .tabBar('')
      }
      .barHeight(0)
      .barMode(BarMode.Fixed)
      .onChange((index: number) => {
        this.currentTab = index
        // 连续点击趋势统计tab 10次才显示测试按钮
        if (index === 2) {
          this.trendTabClickCount++
          if (this.trendTabClickCount >= 10) {
            this.testButtonVisible = true
          }
        } else {
          this.trendTabClickCount = 0
        }
      })
      .animationDuration(300)

      this.CustomTabBar()

      // 测试工具弹窗（放在外层Stack，使TabBar也被模糊）
      if (this.showTestTools) {
        Column()
          .width('100%')
          .height('100%')
          .backdropBlur(20)
          .backgroundColor('rgba(0,0,0,0.15)')
          .onClick(() => {
            this.showTestTools = false
          })
          .zIndex(10)
          .transition(
            TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.EaseInOut })
          )

        Column({ space: 16 }) {
          Text('测试工具')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY)

          Divider().color(AppColors.DIVIDER)

          Column({ space: 12 }) {
            Button('生成30天测试数据')
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor(AppColors.ACCENT)
              .width('100%')
              .height(44)
              .borderRadius(12)
              .onClick(async () => {
                this.vibrateLight()
                const count = await this.trendVm?.generateTestData()
                this.showTestTools = false
                promptAction.showToast({ message: `已生成${count}条测试数据`, duration: 2000 })
              })

            Button('清空所有数据')
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor('#FF6B6B')
              .width('100%')
              .height(44)
              .borderRadius(12)
              .onClick(async () => {
                this.vibrateLight()
                AlertDialog.show({
                  title: '确认清空',
                  message: '确定要删除所有历史数据吗？此操作不可恢复！',
                  primaryButton: {
                    value: '取消',
                    action: () => {}
                  },
                  secondaryButton: {
                    value: '确定删除',
                    fontColor: '#FF6B6B',
                    action: async () => {
                      const count = await this.trendVm?.clearAllData()
                      this.refreshTrendChart()
                      this.refreshBodyFatChart()
                      this.showTestTools = false
                      promptAction.showToast({ message: `已清空${count}条数据`, duration: 2000 })
                    }
                  }
                })
              })

            Button('修改指定日期')
              .fontSize(14)
              .fontColor(AppColors.TEXT_PRIMARY)
              .backgroundColor(AppColors.CARD)
              .width('100%')
              .height(44)
              .borderRadius(12)
              .border({ width: 1, color: AppColors.INPUT_BORDER })
              .onClick(() => {
                this.vibrateLight()
                this.showDateEditDialog = true
                this.showTestTools = false
              })
          }
          .width('100%')

          Text('点击空白处关闭')
            .fontSize(12)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .width(280)
        .padding(24)
        .backgroundColor(AppColors.CARD)
        .borderRadius(20)
        .shadow({
          radius: 20,
          color: 'rgba(0,0,0,0.12)',
          offsetY: 6
        })
        .position({ x: '50%', y: '50%' })
        .translate({ x: '-50%', y: '-50%' })
        .zIndex(11)
        .transition(
          TransitionEffect.OPACITY
            .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 }))
            .animation({ duration: 300, curve: Curve.EaseOut })
        )
      }

      // 日期编辑弹窗（放在外层Stack）
      if (this.showDateEditDialog) {
        this.DateEditDialog()
      }

      // 图表点详情弹窗（放在外层Stack）
      if (this.trendVm?.showPointDetail) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundBlurStyle(BlurStyle.Regular)
          .onClick(() => {
            this.trendVm?.closePointDetail()
          })
          .zIndex(10)
          .transition(
            TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.EaseInOut })
          )

        Column({ space: 12 }) {
          Text(this.trendVm?.selectedPoint?.date ?? '')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY)

          this.DetailRow('体重', this.getWeightText(this.trendVm?.selectedPoint?.weight ?? null))
          this.DetailRow('体脂', this.getBodyFatText(this.trendVm?.selectedPoint?.bodyFat ?? null))

          Text('点击空白处关闭')
            .fontSize(12)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .width(240)
        .padding(24)
        .backgroundColor(AppColors.CARD)
        .borderRadius(20)
        .shadow({
          radius: 20,
          color: 'rgba(0,0,0,0.12)',
          offsetY: 6
        })
        .position({ x: '50%', y: '50%' })
        .translate({ x: '-50%', y: '-50%' })
        .zIndex(11)
        .transition(
          TransitionEffect.OPACITY
            .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 }))
            .animation({ duration: 300, curve: Curve.EaseOut })
        )
      }

      if (this.heatmapVm?.showDetailDialog) {
        Column({ space: 16 }) {
          Text(this.heatmapVm?.selectedCell?.date ?? '')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY)

          Column({ space: 8 }) {
            this.DetailRow('早餐', this.getMealLabel(this.heatmapVm?.selectedCell?.breakfast))
            this.DetailRow('午餐', this.getMealLabel(this.heatmapVm?.selectedCell?.lunch))
            this.DetailRow('晚餐', this.getMealLabel(this.heatmapVm?.selectedCell?.dinner))
          }

          Divider().color(AppColors.DIVIDER)

          Column({ space: 8 }) {
            this.DetailRow('体重', this.heatmapVm?.selectedCell?.weight !== null
              ? `${this.heatmapVm?.selectedCell?.weight} kg` : '未记录')
            this.DetailRow('体脂', this.heatmapVm?.selectedCell?.bodyFat !== null
              ? `${this.heatmapVm?.selectedCell?.bodyFat}%` : '未记录')
          }

          Divider().color(AppColors.DIVIDER)

          Row({ space: 12 }) {
            Button('编辑')
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor(AppColors.ACCENT)
              .layoutWeight(1)
              .height(40)
              .borderRadius(20)
              .onClick(() => {
                this.vibrateLight()
                const cell = this.heatmapVm?.selectedCell
                if (cell) {
                  this.heatmapVm?.startEdit(cell)
                  this.initHeatmapEditFromCell()
                }
              })

            Button('关闭')
              .fontSize(14)
              .fontColor(AppColors.TEXT_SECONDARY)
              .backgroundColor(AppColors.BG)
              .layoutWeight(1)
              .height(40)
              .borderRadius(20)
              .onClick(() => {
                this.vibrateLight()
                this.heatmapVm?.closeDetailDialog()
              })
          }
        }
        .width(280)
        .padding(24)
        .backgroundColor(AppColors.CARD)
        .borderRadius(20)
        .shadow({
          radius: 20,
          color: 'rgba(0,0,0,0.12)',
          offsetY: 6
        })
        .transition(
          TransitionEffect.OPACITY
            .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 }))
            .animation({ duration: 300, curve: Curve.EaseOut })
        )
        .position({ x: '50%', y: '50%' })
        .translate({ x: '-50%', y: '-50%' })
        .zIndex(2)

        Column()
          .width('100%')
          .height('100%')
          .backdropBlur(20)
          .backgroundColor('rgba(0,0,0,0.15)')
          .onClick(() => {
            this.heatmapVm?.closeDetailDialog()
          })
          .zIndex(1)
          .transition(
            TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.EaseInOut })
          )
      }

      // 热力图编辑弹窗
      if (this.heatmapVm?.showEditDialog) {
        this.HeatmapEditDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  CustomTabBar() {
    Column() {
      Row({ space: 0 }) {
        ForEach(['今日记录', '热力图', '趋势统计'], (title: string, index: number) => {
          Column({ space: 6 }) {
            Text(title)
              .fontSize(12)
              .fontColor(this.currentTab === index ? AppColors.ACCENT : AppColors.TEXT_SECONDARY)
              .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Normal)

            Stack() {
              Circle({ width: 4, height: 4 })
                .fill(AppColors.ACCENT)
            }
            .width(4)
            .height(4)
            .scale({ x: this.currentTab === index ? 1 : 0, y: this.currentTab === index ? 1 : 0 })
            .animation({
              duration: 250,
              curve: Curve.EaseInOut
            })
          }
          .layoutWeight(1)
          .height(56)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.currentTab = index
            // 连续点击趋势统计tab 10次才显示测试按钮
            if (index === 2) {
              this.trendTabClickCount++
              if (this.trendTabClickCount >= 10) {
                this.testButtonVisible = true
              }
            } else {
              this.trendTabClickCount = 0
            }
          })
        })
      }
      .width('92%')
      .height(56)
      .backgroundColor(AppColors.CARD)
      .borderRadius(28)
      .shadow({
        radius: 12,
        color: 'rgba(0,0,0,0.08)',
        offsetY: 4
      })
      .margin({ bottom: 48 })
    }
    .width('100%')
    .height(80)
    .justifyContent(FlexAlign.End)
    .backgroundColor('transparent')
    .zIndex(0)
  }

  @Builder
  TodayPage() {
    Column() {
      Text(this.randomTitle)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')
        .padding({ left: 24, right: 24, top: this.statusBarHeight + 56, bottom: 4 })

      Scroll() {
        Column({ space: 0 }) {
          Column({ space: 4 }) {
            Text(this.vm?.getTodayDisplay() ?? '')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TEXT_PRIMARY)

            Text(this.vm?.getWeekdayDisplay() ?? '')
              .fontSize(14)
              .fontColor(AppColors.TEXT_SECONDARY)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 28, right: 28, top: 0, bottom: 20 })

          Column({ space: 20 }) {
            Row() {
              Text('昨日饮食')
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.TEXT_PRIMARY)

              Text(this.vm?.getYesterdayDisplay() ?? '')
                .fontSize(13)
                .fontColor(AppColors.TEXT_SECONDARY)
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)

            MealSegment({
              title: '早餐',
              selectedIndex: this.vm?.yesterdayBreakfast ?? -1,
              onSelect: (index: number | null) => {
                this.vibrateLight()
                if (this.vm) {
                  this.vm.yesterdayBreakfast = index
                }
              }
            })

            MealSegment({
              title: '午餐',
              selectedIndex: this.vm?.yesterdayLunch ?? -1,
              onSelect: (index: number | null) => {
                this.vibrateLight()
                if (this.vm) {
                  this.vm.yesterdayLunch = index
                }
              }
            })

            MealSegment({
              title: '晚餐',
              selectedIndex: this.vm?.yesterdayDinner ?? -1,
              onSelect: (index: number | null) => {
                this.vibrateLight()
                if (this.vm) {
                  this.vm.yesterdayDinner = index
                }
              }
            })
          }
          .width('88%')
          .padding(20)
          .backgroundColor(AppColors.CARD)
          .borderRadius(AppDimens.RADIUS_LG)
          .shadow({
            radius: AppDimens.SHADOW_RADIUS,
            color: AppDimens.SHADOW_COLOR,
            offsetY: AppDimens.SHADOW_OFFSET_Y
          })

          Column({ space: 16 }) {
            Text('今日体重')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TEXT_PRIMARY)

            Row({ space: 12 }) {
              this.InputField('体重', 'kg', this.vm?.weightText ?? '', (val: string) => {
                if (this.vm) {
                  this.vm.weightText = val
                }
              })

              this.InputField('体脂率', '%', this.vm?.bodyFatText ?? '', (val: string) => {
                if (this.vm) {
                  this.vm.bodyFatText = val
                }
              })
            }
            .width('100%')
          }
          .width('88%')
          .padding(20)
          .margin({ top: 16 })
          .backgroundColor(AppColors.CARD)
          .borderRadius(AppDimens.RADIUS_LG)
          .shadow({
            radius: AppDimens.SHADOW_RADIUS,
            color: AppDimens.SHADOW_COLOR,
            offsetY: AppDimens.SHADOW_OFFSET_Y
          })

          Button(this.vm?.isExistingRecord ? '更新记录' : '保存记录')
            .width('60%')
            .height(44)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor(AppColors.ACCENT)
            .borderRadius(22)
            .margin({ left: 24, right: 24, top: 32, bottom: 48 })
            .enabled(!(this.vm?.isSaving ?? false))
            .onClick(async () => {
              this.vibrateLight()
              if (!this.vm) {
                return
              }
              const validation = this.vm.validateInputs()
              if (!validation.valid) {
                promptAction.showToast({ message: validation.message ?? '请检查输入格式', duration: 2000 })
                return
              }
              const success = await this.vm.save()
              if (success) {
                promptAction.showToast({ message: '保存成功', duration: 1500 })
              } else {
                promptAction.showToast({ message: '保存失败，请重试', duration: 1500 })
              }
            })
        }
      }
      .scrollable(ScrollDirection.Vertical)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ top: 0 })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG)
  }

  @Builder
  InputField(label: string, unit: string, value: string, onChange: (val: string) => void) {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(15)
        .fontColor(AppColors.TEXT_SECONDARY)
        .fontWeight(FontWeight.Medium)

      Row() {
        TextInput({ text: value, placeholder: '未填写' })
          .type(InputType.NUMBER_DECIMAL)
          .fontSize(16)
          .fontColor(AppColors.TEXT_PRIMARY)
          .placeholderColor(AppColors.INPUT_BORDER)
          .backgroundColor('transparent')
          .layoutWeight(1)
          .padding({ left: 0, right: 0 })
          .textAlign(TextAlign.Center)
          .onChange((text: string) => {
            onChange(text)
          })

        Text(unit)
          .fontSize(14)
          .fontColor(AppColors.TEXT_SECONDARY)
          .margin({ left: 4 })
      }
      .width('100%')
      .height(44)
      .padding({ left: 12, right: 12 })
      .borderRadius(AppDimens.RADIUS_SM)
      .border({ width: 1, color: AppColors.INPUT_BORDER })
    }
    .layoutWeight(1)
  }

  @Builder
  HeatmapPage() {
    Stack() {
      Column() {
        Text('热力图')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width('100%')
          .padding({ left: 24, right: 24, top: this.statusBarHeight + 56, bottom: 66 })

        Row() {
          Row({ space: 4 }) {
            Text('<')
              .fontSize(20)
              .fontColor(AppColors.ACCENT)
              .padding(8)
              .onClick(() => {
                this.vibrateLight()
                this.heatmapVm?.goToPreviousMonth()
              })

            Text(this.heatmapVm?.getMonthTitle() ?? '')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TEXT_PRIMARY)

            Text('>')
              .fontSize(20)
              .fontColor(AppColors.ACCENT)
              .padding(8)
              .onClick(() => {
                this.vibrateLight()
                this.heatmapVm?.goToNextMonth()
              })
          }
          .alignItems(VerticalAlign.Center)

          Text('今天')
            .fontSize(13)
            .fontColor(AppColors.ACCENT)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(14)
            .backgroundColor(AppColors.ACCENT_LIGHT)
            .onClick(() => {
              this.vibrateLight()
              this.heatmapVm?.goToToday()
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({ left: 24, right: 24, top: 0, bottom: 20 })

        Row({ space: 8 }) {
          Text('清淡')
            .fontSize(11)
            .fontColor(AppColors.TEXT_SECONDARY)

          Row({ space: 3 }) {
            ForEach([0, 1, 2, 3, 4, 5, 6], (score: number) => {
              Stack() {
                Rect({ width: 16, height: 16 })
                  .fill(this.getLegendColor(score))
                  .radius(4)
              }
            })
          }

          Text('放纵')
            .fontSize(11)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .padding({ left: 24, right: 24, bottom: 28 })

        Column({ space: 0 }) {
          Row() {
            ForEach(['一', '二', '三', '四', '五', '六', '日'], (day: string) => {
              Text(day)
                .fontSize(12)
                .fontColor(AppColors.TEXT_SECONDARY)
                .fontWeight(FontWeight.Medium)
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
                .height(32)
            })
          }
          .width('100%')
          .padding({ left: 4, right: 4 })

          ForEach(this.heatmapVm?.weeks ?? [], (week: HeatmapWeek) => {
            Row() {
              ForEach(week.cells, (cell: HeatmapCell) => {
                Stack() {
                  if (cell.isCurrentMonth) {
                    Text(`${cell.day}`)
                      .fontSize(13)
                      .fontColor(cell.hasData ? '#FFFFFF' : AppColors.TEXT_SECONDARY)
                      .fontWeight(cell.date === this.heatmapVm?.getTodayDate()
                        ? FontWeight.Bold : FontWeight.Normal)
                  } else {
                    Text(`${cell.day}`)
                      .fontSize(13)
                      .fontColor(AppColors.INPUT_BORDER)
                  }
                }
                .width(36)
                .height(36)
                .borderRadius(10)
                .backgroundColor(cell.isCurrentMonth && cell.hasData
                  ? (this.heatmapVm?.getCellColor(cell) ?? AppColors.HEATMAP_EMPTY)
                  : 'transparent')
                .border(cell.date === this.heatmapVm?.getTodayDate()
                  ? { width: 2, color: AppColors.ACCENT }
                  : { width: 0, color: 'transparent' })
                .layoutWeight(1)
                .onClick(() => {
                  if (cell.isCurrentMonth) {
                    this.heatmapVm?.onCellClick(cell)
                    this.vibrateLight()
                  }
                })
              })
            }
            .width('100%')
            .height(44)
            .padding({ left: 4, right: 4 })
          })
        }
        .width('88%')
        .padding({ top: 4, bottom: 8 })
        .backgroundColor(AppColors.CARD)
        .borderRadius(AppDimens.RADIUS_LG)
        .shadow({
          radius: AppDimens.SHADOW_RADIUS,
          color: AppDimens.SHADOW_COLOR,
          offsetY: AppDimens.SHADOW_OFFSET_Y
        })

        Row() {
          Column({ space: 4 }) {
            Text(`${this.heatmapVm?.summary.recordedDays ?? 0}`)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.ACCENT)
            Text('已记录')
              .fontSize(12)
              .fontColor(AppColors.TEXT_SECONDARY)
          }
          .layoutWeight(1)

          Column({ space: 4 }) {
            Text(`${this.heatmapVm?.summary.healthyDays ?? 0}`)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.HEATMAP_GREEN)
            Text('健康天')
              .fontSize(12)
              .fontColor(AppColors.TEXT_SECONDARY)
          }
          .layoutWeight(1)

          Column({ space: 4 }) {
            Text(`${this.heatmapVm?.summary.totalDays ?? 0}`)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TEXT_PRIMARY)
            Text('本月天数')
              .fontSize(12)
              .fontColor(AppColors.TEXT_SECONDARY)
          }
          .layoutWeight(1)
        }
        .width('88%')
        .padding(20)
        .margin({ top: 32 })
        .backgroundColor(AppColors.CARD)
        .borderRadius(AppDimens.RADIUS_LG)
        .shadow({
          radius: AppDimens.SHADOW_RADIUS,
          color: AppDimens.SHADOW_COLOR,
          offsetY: AppDimens.SHADOW_OFFSET_Y
        })

        Blank().layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.BG)

    }
    .width('100%')
    .height('100%')
  }

  @Builder
  DetailRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(AppColors.TEXT_SECONDARY)

      Text(value)
        .fontSize(14)
        .fontColor(AppColors.TEXT_PRIMARY)
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
  }

  getMealLabel(value: number | null | undefined): string {
    if (value === null || value === undefined) return '未记录'
    return MEAL_LABELS[value] ?? '未记录'
  }

  getLegendColor(score: number): string {
    const ratio = score / 6
    const hex1 = AppColors.HEATMAP_GREEN.replace('#', '')
    const hex2 = AppColors.HEATMAP_RED.replace('#', '')

    const r1 = parseInt(hex1.substring(0, 2), 16)
    const g1 = parseInt(hex1.substring(2, 4), 16)
    const b1 = parseInt(hex1.substring(4, 6), 16)

    const r2 = parseInt(hex2.substring(0, 2), 16)
    const g2 = parseInt(hex2.substring(2, 4), 16)
    const b2 = parseInt(hex2.substring(4, 6), 16)

    const r = Math.round(r1 + (r2 - r1) * ratio)
    const g = Math.round(g1 + (g2 - g1) * ratio)
    const b = Math.round(b1 + (b2 - b1) * ratio)

    return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`
  }

  @Builder
  TrendPage() {
    Column() {
        Row() {
          Text('趋势统计')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY)
            .layoutWeight(1)

          if (this.testButtonVisible) {
            Circle({ width: 14, height: 14 })
              .fill('#FF6B6B')
              .onClick(() => {
                this.vibrateLight()
                this.showTestTools = true
              })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 24, right: 24, top: this.statusBarHeight + 56, bottom: 56 })

        Row() {
          Row({ space: 4 }) {
            Text('<')
              .fontSize(20)
              .fontColor(AppColors.ACCENT)
              .padding(8)
              .onClick(async () => {
                this.vibrateLight()
                await this.trendVm?.goToPrevious()
                this.refreshTrendChart()
                this.refreshBodyFatChart()
              })

            Text(this.trendVm?.getRangeTitle() ?? '')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)

            Text('>')
              .fontSize(20)
              .fontColor(this.trendVm?.isAtLatest() ? AppColors.INPUT_BORDER : AppColors.ACCENT)
              .padding(8)
              .onClick(async () => {
                if (this.trendVm?.isAtLatest()) return
                this.vibrateLight()
                await this.trendVm?.goToNext()
                this.refreshTrendChart()
                this.refreshBodyFatChart()
              })
          }
          .alignItems(VerticalAlign.Center)

          Row({ space: 8 }) {
            ForEach(this.trendVm?.getPeriodOptions() ?? [], (option: string, index: number) => {
              Button(option)
                .fontSize(14)
                .fontColor(this.trendVm?.getPeriodIndex() === index ? '#FFFFFF' : AppColors.TEXT_SECONDARY)
                .backgroundColor(this.trendVm?.getPeriodIndex() === index ? AppColors.ACCENT : AppColors.CARD)
                .width(48)
                .height(32)
                .borderRadius(16)
                .onClick(async () => {
                  await this.trendVm?.setPeriodByIndex(index)
                  this.refreshTrendChart()
                  this.refreshBodyFatChart()
                })
            })
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .padding({ left: 16, right: 16, bottom: 20 })

        List({ space: 16 }) {
          ListItem() {
            Column({ space: 12 }) {
              Row() {
                Text('体重趋势')
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppColors.TEXT_PRIMARY)

                Text(this.trendVm?.getRangeTitle() ?? '')
                  .fontSize(13)
                  .fontColor(AppColors.TEXT_SECONDARY)
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)

              Stack() {
                Canvas(this.trendChartContext)
                  .width('100%')
                  .height(200)
                  .backgroundColor(AppColors.BG)
                  .borderRadius(AppDimens.RADIUS_MD)
                  .onReady(() => {
                    this.refreshTrendChart()
                  })
                  .onClick((event) => {
                    this.handleChartClick(event.x, event.y)
                  })
              }
              .width('100%')
              .height(200)
              .borderRadius(AppDimens.RADIUS_MD)
              .clip(true)
            }
            .width('88%')
            .padding(20)
            .backgroundColor(AppColors.CARD)
            .borderRadius(AppDimens.RADIUS_LG)
            .shadow({
              radius: AppDimens.SHADOW_RADIUS,
              color: AppDimens.SHADOW_COLOR,
              offsetY: AppDimens.SHADOW_OFFSET_Y
            })
          }

          ListItem() {
            Column({ space: 12 }) {
              Row() {
                Text('体脂趋势')
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppColors.TEXT_PRIMARY)

                Text(this.trendVm?.getRangeTitle() ?? '')
                  .fontSize(13)
                  .fontColor(AppColors.TEXT_SECONDARY)
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)

              Stack() {
                Canvas(this.bodyFatChartContext)
                  .width('100%')
                  .height(200)
                  .backgroundColor(AppColors.BG)
                  .borderRadius(AppDimens.RADIUS_MD)
                  .onReady(() => {
                    this.refreshBodyFatChart()
                  })
                  .onClick((event) => {
                    this.handleBodyFatChartClick(event.x, event.y)
                  })
              }
              .width('100%')
              .height(200)
              .borderRadius(AppDimens.RADIUS_MD)
              .clip(true)
            }
            .width('88%')
            .padding(20)
            .backgroundColor(AppColors.CARD)
            .borderRadius(AppDimens.RADIUS_LG)
            .shadow({
              radius: AppDimens.SHADOW_RADIUS,
              color: AppDimens.SHADOW_COLOR,
              offsetY: AppDimens.SHADOW_OFFSET_Y
            })
          }

          ListItem() {
            Column({ space: 16 }) {
              Text('健康统计')
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.TEXT_PRIMARY)
                .alignSelf(ItemAlign.Start)

              Row() {
                Column({ space: 4 }) {
                  Text('饮食健康率')
                    .fontSize(13)
                    .fontColor(AppColors.TEXT_SECONDARY)

                  Text(`${this.trendVm?.stats.healthyRate ?? 0}%`)
                    .fontSize(28)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppColors.ACCENT)
                }

                Column({ space: 4 }) {
                  Text('记录天数')
                    .fontSize(13)
                    .fontColor(AppColors.TEXT_SECONDARY)

                  Text(`${this.trendVm?.stats.totalDays ?? 0}天`)
                    .fontSize(28)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(AppColors.TEXT_PRIMARY)
                }
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceAround)

              Divider().color(AppColors.DIVIDER)

              Row() {
                Column({ space: 4 }) {
                  Text('平均体重')
                    .fontSize(13)
                    .fontColor(AppColors.TEXT_SECONDARY)

                  Text(this.trendVm?.stats.avgWeight !== null
                    ? `${this.trendVm?.stats.avgWeight.toFixed(1)} kg` : '--')
                    .fontSize(20)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.TEXT_PRIMARY)
                }

                Column({ space: 4 }) {
                  Text('体重变化')
                    .fontSize(13)
                    .fontColor(AppColors.TEXT_SECONDARY)

                  Text(this.getWeightChangeText(this.trendVm?.stats.weightChange ?? null))
                    .fontSize(20)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.getWeightChangeColor(this.trendVm?.stats.weightChange ?? null))
                }
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceAround)
            }
            .width('88%')
            .padding(20)
            .backgroundColor(AppColors.CARD)
            .borderRadius(AppDimens.RADIUS_LG)
            .shadow({
              radius: AppDimens.SHADOW_RADIUS,
              color: AppDimens.SHADOW_COLOR,
              offsetY: AppDimens.SHADOW_OFFSET_Y
            })
          }

          ListItem() {
            Column().height(48)
          }
        }
        .listDirection(Axis.Vertical)
        .edgeEffect(EdgeEffect.Spring)
        .padding({ top: 0 })
        .layoutWeight(1)
        .alignListItem(ListItemAlign.Center)
      }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG)
  }

  private drawTrendChart(): void {
    const context = this.trendChartContext
    const chartData = this.trendVm?.getWeightChartData() ?? []
    // 先清空画布
    context.clearRect(0, 0, context.width, context.height)
    if (chartData.length < 2) {
      context.fillStyle = AppColors.TEXT_SECONDARY
      context.font = '30px sans-serif'
      context.textAlign = 'center'
      context.fillText('暂无数据', context.width / 2, context.height / 2)
      return
    }

    const padding = 40
    const chartWidth = context.width - padding * 2
    const chartHeight = context.height - padding * 2
    const bounds = this.trendVm?.getChartBounds() ?? { minWeight: 0, maxWeight: 100 }

    context.clearRect(0, 0, context.width, context.height)

    context.strokeStyle = AppColors.DIVIDER
    context.lineWidth = 1
    context.beginPath()
    for (let i = 0; i <= 4; i++) {
      const y = padding + (chartHeight / 4) * i
      context.moveTo(padding, y)
      context.lineTo(padding + chartWidth, y)
    }
    context.stroke()

    context.fillStyle = AppColors.TEXT_SECONDARY
    context.font = '26px sans-serif'
    context.textAlign = 'right'
    context.textBaseline = 'middle'
    for (let i = 0; i <= 4; i++) {
      const weight = bounds.maxWeight - ((bounds.maxWeight - bounds.minWeight) / 4) * i
      const y = padding + (chartHeight / 4) * i
      context.fillText(weight.toFixed(1), padding - 12, y)
    }

    // 绘制动画线条 - 根据进度绘制部分线段
    const progress = this.chartAnimationProgress
    const maxIndex = (chartData.length - 1) * progress
    const integerPart = Math.floor(maxIndex)
    const fractionPart = maxIndex - integerPart

    context.strokeStyle = AppColors.ACCENT
    context.lineWidth = 2
    context.beginPath()

    for (let i = 0; i <= integerPart && i < chartData.length; i++) {
      const point = chartData[i]
      const x = padding + point.x * chartWidth
      const y = padding + point.y * chartHeight
      if (i === 0) {
        context.moveTo(x, y)
      } else {
        context.lineTo(x, y)
      }
    }

    // 绘制小数部分的线段（动画中的当前段）
    if (fractionPart > 0 && integerPart < chartData.length - 1) {
      const startPoint = chartData[integerPart]
      const endPoint = chartData[integerPart + 1]
      const startX = padding + startPoint.x * chartWidth
      const startY = padding + startPoint.y * chartHeight
      const endX = padding + endPoint.x * chartWidth
      const endY = padding + endPoint.y * chartHeight
      const currentX = startX + (endX - startX) * fractionPart
      const currentY = startY + (endY - startY) * fractionPart
      context.lineTo(currentX, currentY)
    }
    context.stroke()

    // 绘制数据点（只显示已绘制部分的点）
    const visiblePointsCount = Math.ceil(maxIndex) + 1
    for (let i = 0; i < visiblePointsCount && i < chartData.length; i++) {
      const point = chartData[i]
      const x = padding + point.x * chartWidth
      const y = padding + point.y * chartHeight

      // 最后一个点添加缩放动画效果
      let radius = 5
      if (i === integerPart && fractionPart > 0) {
        radius = 3 + 2 * fractionPart
      }

      context.fillStyle = AppColors.CARD
      context.beginPath()
      context.arc(x, y, radius, 0, Math.PI * 2)
      context.fill()

      context.fillStyle = AppColors.ACCENT
      context.beginPath()
      context.arc(x, y, radius - 2, 0, Math.PI * 2)
      context.fill()
    }

    // 绘制X轴日期标签（智能密度）
    const period = this.trendVm?.period ?? 'week'
    let labelInterval = 1
    if (period === 'month') {
      labelInterval = 7 // 月视图每7天显示一个
    } else if (period === 'year') {
      labelInterval = 30 // 年视图每月显示一个
    }
    context.fillStyle = AppColors.TEXT_SECONDARY
    context.font = '26px sans-serif'
    context.textAlign = 'center'
    context.textBaseline = 'alphabetic'
    for (let i = 0; i < chartData.length; i++) {
      if (i % labelInterval === 0 || i === chartData.length - 1) {
        const point = chartData[i]
        const x = padding + point.x * chartWidth
        const y = context.height - padding + 20
        context.fillText(point.point.displayDate, x, y)
      }
    }

    // 绘制选中点的气泡提示
    if (this.selectedPointIndex >= 0 && this.selectedPointIndex < chartData.length && this.bubbleAnimationProgress > 0) {
      const point = chartData[this.selectedPointIndex]
      const x = padding + point.x * chartWidth
      const y = padding + point.y * chartHeight
      const weight = point.point.weight

      if (weight !== null) {
        const bubbleText = `${weight.toFixed(1)}kg`
        context.font = 'bold 38px sans-serif'
        const textWidth = context.measureText(bubbleText).width
        const bubblePadding = 10
        const bubbleWidth = textWidth + bubblePadding * 2
        const bubbleHeight = 36
        // 判断气泡位置：太靠顶部时显示在点下方
        const bubbleAboveOffset = 50
        const bubbleBelowOffset = 12
        const isBubbleAbove = y > 50
        const bubbleY = isBubbleAbove
          ? y - bubbleAboveOffset * this.bubbleAnimationProgress
          : y + bubbleBelowOffset * this.bubbleAnimationProgress

        // 绘制气泡背景（磨砂玻璃效果）
        const scale = this.bubbleAnimationProgress
        const centerX = x
        const centerY = bubbleY + bubbleHeight / 2

        // 保存当前状态，隔离滤镜效果
        context.save()
        context.translate(centerX, centerY)
        context.scale(scale, scale)
        context.translate(-centerX, -centerY)

        // 圆角矩形气泡
        context.fillStyle = AppColors.ACCENT
        const radius = 6
        context.beginPath()
        context.moveTo(x - bubbleWidth / 2 + radius, bubbleY)
        context.lineTo(x + bubbleWidth / 2 - radius, bubbleY)
        context.arcTo(x + bubbleWidth / 2, bubbleY, x + bubbleWidth / 2, bubbleY + radius, radius)
        context.lineTo(x + bubbleWidth / 2, bubbleY + bubbleHeight - radius)
        context.arcTo(x + bubbleWidth / 2, bubbleY + bubbleHeight, x + bubbleWidth / 2 - radius, bubbleY + bubbleHeight, radius)
        context.lineTo(x - bubbleWidth / 2 + radius, bubbleY + bubbleHeight)
        context.arcTo(x - bubbleWidth / 2, bubbleY + bubbleHeight, x - bubbleWidth / 2, bubbleY + bubbleHeight - radius, radius)
        context.lineTo(x - bubbleWidth / 2, bubbleY + radius)
        context.arcTo(x - bubbleWidth / 2, bubbleY, x - bubbleWidth / 2 + radius, bubbleY, radius)
        context.closePath()
        context.fill()

        // 绘制三角形箭头
        context.beginPath()
        if (isBubbleAbove) {
          // 气泡在点上方，箭头朝下
          context.moveTo(x - 6, bubbleY + bubbleHeight)
          context.lineTo(x + 6, bubbleY + bubbleHeight)
          context.lineTo(x, bubbleY + bubbleHeight + 6)
        } else {
          // 气泡在点下方，箭头朝上
          context.moveTo(x - 6, bubbleY)
          context.lineTo(x + 6, bubbleY)
          context.lineTo(x, bubbleY - 6)
        }
        context.closePath()
        context.fill()

        context.restore()

        // 绘制文字
        context.fillStyle = '#FFFFFF'
        context.textAlign = 'center'
        context.textBaseline = 'middle'
        context.fillText(bubbleText, x, bubbleY + bubbleHeight / 2)
      }
    }
  }

  // 处理图表点击事件
  private handleChartClick(clickX: number, clickY: number): void {
    const chartData = this.trendVm?.getWeightChartData() ?? []
    if (chartData.length < 2) return

    const padding = 40
    const rectWidth = this.trendChartContext.width
    const rectHeight = this.trendChartContext.height
    const chartWidth = rectWidth - padding * 2
    const chartHeight = rectHeight - padding * 2

    // 找到最近的点
    let minDistance = Infinity
    let nearestIndex = -1

    for (let i = 0; i < chartData.length; i++) {
      const point = chartData[i]
      const px: number = padding + point.x * chartWidth
      const py: number = padding + point.y * chartHeight
      const distance = Math.sqrt((clickX - px) ** 2 + (clickY - py) ** 2)

      if (distance < minDistance) {
        minDistance = distance
        nearestIndex = i
      }
    }

    // 如果点击距离在20像素内，则选中该点
    if (minDistance <= 20) {
      if (this.selectedPointIndex === nearestIndex) {
        // 点击同一个点，关闭气泡
        this.hideBubble()
      } else {
        // 选中新点，显示气泡动画
        this.selectedPointIndex = nearestIndex
        this.showBubble()
        this.vibrateLight()
      }
    } else {
      // 点击空白处，关闭气泡
      this.hideBubble()
    }
  }

  // 显示气泡动画
  private showBubble(): void {
    // 停止之前的动画
    this.bubbleAnimator?.cancel()
    this.bubbleAnimationProgress = 0
    this.drawTrendChart()

    // 创建展开动画
    this.bubbleAnimator = Animator.create({
      duration: 200,
      easing: 'ease-out',
      fill: 'forwards',
      begin: 0,
      end: 100,
      delay: 0,
      direction: 'normal',
      iterations: 1
    })

    this.bubbleAnimator.onFrame = (progress: number) => {
      this.bubbleAnimationProgress = progress / 100
      this.drawTrendChart()
    }

    this.bubbleAnimator.onFinish = () => {
      this.bubbleAnimationProgress = 1
      this.drawTrendChart()
    }

    this.bubbleAnimator.play()
  }

  // 隐藏气泡动画
  private hideBubble(): void {
    if (this.selectedPointIndex < 0) return

    this.bubbleAnimator?.cancel()

    this.bubbleAnimator = Animator.create({
      duration: 150,
      easing: 'ease-in',
      fill: 'forwards',
      begin: 100,
      end: 0,
      delay: 0,
      direction: 'normal',
      iterations: 1
    })

    this.bubbleAnimator.onFrame = (progress: number) => {
      this.bubbleAnimationProgress = progress / 100
      this.drawTrendChart()
    }

    this.bubbleAnimator.onFinish = () => {
      this.selectedPointIndex = -1
      this.bubbleAnimationProgress = 0
      this.drawTrendChart()
    }

    this.bubbleAnimator.play()
  }

  getWeightChangeText(change: number | null): string {
    if (change === null) return '--'
    const sign = change > 0 ? '+' : ''
    return `${sign}${change.toFixed(1)} kg`
  }

  getWeightChangeColor(change: number | null): string {
    if (change === null) return AppColors.TEXT_PRIMARY
    if (change < 0) return AppColors.HEATMAP_GREEN
    if (change > 0) return AppColors.HEATMAP_RED
    return AppColors.TEXT_PRIMARY
  }

  getWeightText(weight: number | null): string {
    if (weight === null) return '未记录'
    return `${weight} kg`
  }

  getBodyFatText(bodyFat: number | null): string {
    if (bodyFat === null) return '未记录'
    return `${bodyFat}%`
  }

  // 强制重绘趋势图表
  private refreshTrendChart(): void {
    // 停止之前的动画
    this.chartAnimator?.cancel()
    this.chartAnimator = null

    // 重置选中点和气泡
    this.selectedPointIndex = -1
    this.bubbleAnimationProgress = 0
    this.bubbleAnimator?.cancel()

    // 重置动画进度
    this.chartAnimationProgress = 0
    this.drawTrendChart()

    // 创建Animator实现线条绘制动画
    const animatorResult = Animator.create({
      duration: 500,
      easing: 'ease-in-out',
      fill: 'forwards',
      begin: 0,
      end: 100,
      delay: 0,
      direction: 'normal',
      iterations: 1
    })

    animatorResult.onFrame = (progress: number) => {
      this.chartAnimationProgress = progress / 100
      this.drawTrendChart()
    }

    animatorResult.onFinish = () => {
      this.chartAnimationProgress = 1
      this.drawTrendChart()
    }

    this.chartAnimator = animatorResult
    animatorResult.play()
  }

  // 体脂趋势图表绘制
  private drawBodyFatChart(): void {
    const context = this.bodyFatChartContext
    const chartData = this.trendVm?.getBodyFatChartData() ?? []
    context.clearRect(0, 0, context.width, context.height)
    if (chartData.length < 2) {
      context.fillStyle = AppColors.TEXT_SECONDARY
      context.font = '30px sans-serif'
      context.textAlign = 'center'
      context.fillText('暂无数据', context.width / 2, context.height / 2)
      return
    }

    const padding = 40
    const chartWidth = context.width - padding * 2
    const chartHeight = context.height - padding * 2
    const bounds = this.trendVm?.getBodyFatChartBounds() ?? { minWeight: 5, maxWeight: 40 }

    context.clearRect(0, 0, context.width, context.height)

    context.strokeStyle = AppColors.DIVIDER
    context.lineWidth = 1
    context.beginPath()
    for (let i = 0; i <= 4; i++) {
      const y = padding + (chartHeight / 4) * i
      context.moveTo(padding, y)
      context.lineTo(padding + chartWidth, y)
    }
    context.stroke()

    context.fillStyle = AppColors.TEXT_SECONDARY
    context.font = '26px sans-serif'
    context.textAlign = 'right'
    context.textBaseline = 'middle'
    for (let i = 0; i <= 4; i++) {
      const bodyFat = bounds.maxWeight - ((bounds.maxWeight - bounds.minWeight) / 4) * i
      const y = padding + (chartHeight / 4) * i
      context.fillText(bodyFat.toFixed(1), padding - 12, y)
    }

    // 绘制动画线条
    const progress = this.bodyFatChartAnimationProgress
    const maxIndex = (chartData.length - 1) * progress
    const integerPart = Math.floor(maxIndex)
    const fractionPart = maxIndex - integerPart

    context.strokeStyle = '#FF9500' // 体脂用橙色
    context.lineWidth = 2
    context.beginPath()

    for (let i = 0; i <= integerPart && i < chartData.length; i++) {
      const point = chartData[i]
      const x = padding + point.x * chartWidth
      const y = padding + point.y * chartHeight
      if (i === 0) {
        context.moveTo(x, y)
      } else {
        context.lineTo(x, y)
      }
    }

    if (fractionPart > 0 && integerPart < chartData.length - 1) {
      const startPoint = chartData[integerPart]
      const endPoint = chartData[integerPart + 1]
      const startX = padding + startPoint.x * chartWidth
      const startY = padding + startPoint.y * chartHeight
      const endX = padding + endPoint.x * chartWidth
      const endY = padding + endPoint.y * chartHeight
      const currentX = startX + (endX - startX) * fractionPart
      const currentY = startY + (endY - startY) * fractionPart
      context.lineTo(currentX, currentY)
    }
    context.stroke()

    // 绘制数据点
    const visiblePointsCount = Math.ceil(maxIndex) + 1
    for (let i = 0; i < visiblePointsCount && i < chartData.length; i++) {
      const point = chartData[i]
      const x = padding + point.x * chartWidth
      const y = padding + point.y * chartHeight

      let radius = 5
      if (i === integerPart && fractionPart > 0) {
        radius = 3 + 2 * fractionPart
      }

      context.fillStyle = AppColors.CARD
      context.beginPath()
      context.arc(x, y, radius, 0, Math.PI * 2)
      context.fill()

      context.fillStyle = '#FF9500'
      context.beginPath()
      context.arc(x, y, radius - 2, 0, Math.PI * 2)
      context.fill()
    }

    // 绘制X轴日期标签
    const period = this.trendVm?.period ?? 'week'
    let labelInterval = 1
    if (period === 'month') {
      labelInterval = 7
    } else if (period === 'year') {
      labelInterval = 30
    }
    context.fillStyle = AppColors.TEXT_SECONDARY
    context.font = '26px sans-serif'
    context.textAlign = 'center'
    context.textBaseline = 'alphabetic'
    for (let i = 0; i < chartData.length; i++) {
      if (i % labelInterval === 0 || i === chartData.length - 1) {
        const point = chartData[i]
        const x = padding + point.x * chartWidth
        const y = context.height - padding + 20
        context.fillText(point.point.displayDate, x, y)
      }
    }

    // 绘制选中点的气泡提示
    if (this.bodyFatSelectedPointIndex >= 0 && this.bodyFatSelectedPointIndex < chartData.length && this.bodyFatBubbleAnimationProgress > 0) {
      const point = chartData[this.bodyFatSelectedPointIndex]
      const x = padding + point.x * chartWidth
      const y = padding + point.y * chartHeight
      const bodyFat = point.point.bodyFat

      if (bodyFat !== null) {
        const bubbleText = `${bodyFat.toFixed(1)}%`
        context.font = 'bold 38px sans-serif'
        const textWidth = context.measureText(bubbleText).width
        const bubblePadding = 10
        const bubbleWidth = textWidth + bubblePadding * 2
        const bubbleHeight = 36
        const bubbleAboveOffset = 50
        const bubbleBelowOffset = 12
        const isBubbleAbove = y > 50
        const bubbleY = isBubbleAbove
          ? y - bubbleAboveOffset * this.bodyFatBubbleAnimationProgress
          : y + bubbleBelowOffset * this.bodyFatBubbleAnimationProgress

        context.save()
        context.translate(x, bubbleY + bubbleHeight / 2)
        context.scale(this.bodyFatBubbleAnimationProgress, this.bodyFatBubbleAnimationProgress)
        context.translate(-x, -(bubbleY + bubbleHeight / 2))

        context.fillStyle = '#FF9500'
        const radius = 6
        context.beginPath()
        context.moveTo(x - bubbleWidth / 2 + radius, bubbleY)
        context.lineTo(x + bubbleWidth / 2 - radius, bubbleY)
        context.arcTo(x + bubbleWidth / 2, bubbleY, x + bubbleWidth / 2, bubbleY + radius, radius)
        context.lineTo(x + bubbleWidth / 2, bubbleY + bubbleHeight - radius)
        context.arcTo(x + bubbleWidth / 2, bubbleY + bubbleHeight, x + bubbleWidth / 2 - radius, bubbleY + bubbleHeight, radius)
        context.lineTo(x - bubbleWidth / 2 + radius, bubbleY + bubbleHeight)
        context.arcTo(x - bubbleWidth / 2, bubbleY + bubbleHeight, x - bubbleWidth / 2, bubbleY + bubbleHeight - radius, radius)
        context.lineTo(x - bubbleWidth / 2, bubbleY + radius)
        context.arcTo(x - bubbleWidth / 2, bubbleY, x - bubbleWidth / 2 + radius, bubbleY, radius)
        context.closePath()
        context.fill()

        context.beginPath()
        if (isBubbleAbove) {
          context.moveTo(x - 6, bubbleY + bubbleHeight)
          context.lineTo(x + 6, bubbleY + bubbleHeight)
          context.lineTo(x, bubbleY + bubbleHeight + 6)
        } else {
          context.moveTo(x - 6, bubbleY)
          context.lineTo(x + 6, bubbleY)
          context.lineTo(x, bubbleY - 6)
        }
        context.closePath()
        context.fill()

        context.restore()

        context.fillStyle = '#FFFFFF'
        context.textAlign = 'center'
        context.textBaseline = 'middle'
        context.fillText(bubbleText, x, bubbleY + bubbleHeight / 2)
      }
    }
  }

  // 处理体脂图表点击事件
  private handleBodyFatChartClick(clickX: number, clickY: number): void {
    const chartData = this.trendVm?.getBodyFatChartData() ?? []
    if (chartData.length < 2) return

    const padding = 40
    const rectWidth = this.bodyFatChartContext.width
    const rectHeight = this.bodyFatChartContext.height
    const chartWidth = rectWidth - padding * 2
    const chartHeight = rectHeight - padding * 2

    let minDistance = Infinity
    let nearestIndex = -1

    for (let i = 0; i < chartData.length; i++) {
      const point = chartData[i]
      const px: number = padding + point.x * chartWidth
      const py: number = padding + point.y * chartHeight
      const distance = Math.sqrt((clickX - px) ** 2 + (clickY - py) ** 2)

      if (distance < minDistance) {
        minDistance = distance
        nearestIndex = i
      }
    }

    if (minDistance <= 20) {
      if (this.bodyFatSelectedPointIndex === nearestIndex) {
        this.hideBodyFatBubble()
      } else {
        this.bodyFatSelectedPointIndex = nearestIndex
        this.showBodyFatBubble()
        this.vibrateLight()
      }
    } else {
      this.hideBodyFatBubble()
    }
  }

  // 显示体脂气泡动画
  private showBodyFatBubble(): void {
    this.bodyFatBubbleAnimator?.cancel()
    this.bodyFatBubbleAnimationProgress = 0
    this.drawBodyFatChart()

    this.bodyFatBubbleAnimator = Animator.create({
      duration: 200,
      easing: 'ease-out',
      fill: 'forwards',
      begin: 0,
      end: 100,
      delay: 0,
      direction: 'normal',
      iterations: 1
    })

    this.bodyFatBubbleAnimator.onFrame = (progress: number) => {
      this.bodyFatBubbleAnimationProgress = progress / 100
      this.drawBodyFatChart()
    }

    this.bodyFatBubbleAnimator.onFinish = () => {
      this.bodyFatBubbleAnimationProgress = 1
      this.drawBodyFatChart()
    }

    this.bodyFatBubbleAnimator.play()
  }

  // 隐藏体脂气泡动画
  private hideBodyFatBubble(): void {
    if (this.bodyFatSelectedPointIndex < 0) return

    this.bodyFatBubbleAnimator?.cancel()

    this.bodyFatBubbleAnimator = Animator.create({
      duration: 150,
      easing: 'ease-in',
      fill: 'forwards',
      begin: 100,
      end: 0,
      delay: 0,
      direction: 'normal',
      iterations: 1
    })

    this.bodyFatBubbleAnimator.onFrame = (progress: number) => {
      this.bodyFatBubbleAnimationProgress = progress / 100
      this.drawBodyFatChart()
    }

    this.bodyFatBubbleAnimator.onFinish = () => {
      this.bodyFatSelectedPointIndex = -1
      this.bodyFatBubbleAnimationProgress = 0
      this.drawBodyFatChart()
    }

    this.bodyFatBubbleAnimator.play()
  }

  // 刷新体脂趋势图表
  private refreshBodyFatChart(): void {
    this.bodyFatChartAnimator?.cancel()
    this.bodyFatChartAnimator = null

    this.bodyFatSelectedPointIndex = -1
    this.bodyFatBubbleAnimationProgress = 0
    this.bodyFatBubbleAnimator?.cancel()

    this.bodyFatChartAnimationProgress = 0
    this.drawBodyFatChart()

    const animatorResult = Animator.create({
      duration: 500,
      easing: 'ease-in-out',
      fill: 'forwards',
      begin: 0,
      end: 100,
      delay: 0,
      direction: 'normal',
      iterations: 1
    })

    animatorResult.onFrame = (progress: number) => {
      this.bodyFatChartAnimationProgress = progress / 100
      this.drawBodyFatChart()
    }

    animatorResult.onFinish = () => {
      this.bodyFatChartAnimationProgress = 1
      this.drawBodyFatChart()
    }

    this.bodyFatChartAnimator = animatorResult
    animatorResult.play()
  }

  // 日期编辑弹窗
  @Builder
  DateEditDialog() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0,0,0,0.4)')
      .onClick(() => {
        this.showDateEditDialog = false
        this.editingRecord = null
      })
      .zIndex(12)

    Column({ space: 16 }) {
      Text(this.editingRecord ? `编辑 ${this.editingRecord.date}` : '输入日期')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)

      Divider().color(AppColors.DIVIDER)

      if (!this.editingRecord) {
        // 输入日期
        Column({ space: 8 }) {
          Text('日期 (YYYY-MM-DD)')
            .fontSize(13)
            .fontColor(AppColors.TEXT_SECONDARY)
            .alignSelf(ItemAlign.Start)

          TextInput({ text: this.editDateText, placeholder: '例如: 2024-01-15' })
            .fontSize(15)
            .fontColor(AppColors.TEXT_PRIMARY)
            .placeholderColor(AppColors.TEXT_SECONDARY)
            .backgroundColor(AppColors.BG)
            .height(44)
            .borderRadius(8)
            .padding({ left: 12, right: 12 })
            .onChange((text: string) => {
              this.editDateText = text
            })
        }
        .width('100%')

        Row({ space: 12 }) {
          Button('取消')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .backgroundColor(AppColors.BG)
            .layoutWeight(1)
            .height(44)
            .borderRadius(12)
            .onClick(() => {
              this.showDateEditDialog = false
              this.editDateText = ''
            })

          Button('查询')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor(AppColors.ACCENT)
            .layoutWeight(1)
            .height(44)
            .borderRadius(12)
            .onClick(async () => {
              this.vibrateLight()
              const dateRegex = /^\d{4}-\d{2}-\d{2}$/
              if (!dateRegex.test(this.editDateText)) {
                promptAction.showToast({ message: '日期格式不正确，请使用 YYYY-MM-DD', duration: 2000 })
                return
              }
              const record = await this.trendVm?.queryByDate(this.editDateText)
              if (record) {
                this.editingRecord = record
                this.editBreakfast = record.breakfast ?? -1
                this.editLunch = record.lunch ?? -1
                this.editDinner = record.dinner ?? -1
                this.editWeightText = record.weight !== null ? String(record.weight) : ''
                this.editBodyFatText = record.bodyFat !== null ? String(record.bodyFat) : ''
              } else {
                // 创建新记录
                this.editingRecord = createEmptyRecord(this.editDateText)
                this.editBreakfast = -1
                this.editLunch = -1
                this.editDinner = -1
                this.editWeightText = ''
                this.editBodyFatText = ''
              }
            })
        }
        .width('100%')
      } else {
        // 编辑表单
        Column({ space: 16 }) {
          // 三餐选择
          Column({ space: 8 }) {
            Text('早餐')
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
              .alignSelf(ItemAlign.Start)
            this.EditMealSegment((index) => { this.editBreakfast = index }, this.editBreakfast)
          }
          .width('100%')

          Column({ space: 8 }) {
            Text('午餐')
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
              .alignSelf(ItemAlign.Start)
            this.EditMealSegment((index) => { this.editLunch = index }, this.editLunch)
          }
          .width('100%')

          Column({ space: 8 }) {
            Text('晚餐')
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
              .alignSelf(ItemAlign.Start)
            this.EditMealSegment((index) => { this.editDinner = index }, this.editDinner)
          }
          .width('100%')

          Divider().color(AppColors.DIVIDER)

          // 体重体脂
          Row({ space: 12 }) {
            Column({ space: 4 }) {
              Text('体重 (kg)')
                .fontSize(13)
                .fontColor(AppColors.TEXT_SECONDARY)
              TextInput({ text: this.editWeightText, placeholder: '未填写' })
                .type(InputType.NUMBER_DECIMAL)
                .fontSize(15)
                .fontColor(AppColors.TEXT_PRIMARY)
                .backgroundColor(AppColors.BG)
                .height(44)
                .borderRadius(8)
                .textAlign(TextAlign.Center)
                .onChange((text: string) => {
                  this.editWeightText = text
                })
            }
            .layoutWeight(1)

            Column({ space: 4 }) {
              Text('体脂 (%)')
                .fontSize(13)
                .fontColor(AppColors.TEXT_SECONDARY)
              TextInput({ text: this.editBodyFatText, placeholder: '未填写' })
                .type(InputType.NUMBER_DECIMAL)
                .fontSize(15)
                .fontColor(AppColors.TEXT_PRIMARY)
                .backgroundColor(AppColors.BG)
                .height(44)
                .borderRadius(8)
                .textAlign(TextAlign.Center)
                .onChange((text: string) => {
                  this.editBodyFatText = text
                })
            }
            .layoutWeight(1)
          }
          .width('100%')

          // 操作按钮
          Row({ space: 12 }) {
            Button('取消')
              .fontSize(14)
              .fontColor(AppColors.TEXT_SECONDARY)
              .backgroundColor(AppColors.BG)
              .layoutWeight(1)
              .height(44)
              .borderRadius(12)
              .onClick(() => {
                this.editingRecord = null
                this.editDateText = ''
              })

            Button('删除')
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor('#FF6B6B')
              .width(70)
              .height(44)
              .borderRadius(12)
              .onClick(async () => {
                this.vibrateLight()
                const success = await this.trendVm?.deleteRecord(this.editingRecord!.date)
                if (success) {
                  this.refreshTrendChart() // 触发图表重绘
                  this.refreshBodyFatChart()
                  promptAction.showToast({ message: '删除成功', duration: 1500 })
                  this.showDateEditDialog = false
                  this.editingRecord = null
                  this.editDateText = ''
                }
              })

            Button('保存')
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor(AppColors.ACCENT)
              .layoutWeight(1)
              .height(44)
              .borderRadius(12)
              .onClick(async () => {
                this.vibrateLight()
                const weight = this.editWeightText ? parseFloat(this.editWeightText) : null
                const bodyFat = this.editBodyFatText ? parseFloat(this.editBodyFatText) : null

                const record: DailyRecord = {
                  date: this.editingRecord!.date,
                  breakfast: this.editBreakfast >= 0 ? this.editBreakfast : null,
                  lunch: this.editLunch >= 0 ? this.editLunch : null,
                  dinner: this.editDinner >= 0 ? this.editDinner : null,
                  weight: weight,
                  bodyFat: bodyFat
                }

                await this.trendVm?.saveRecord(record)
                this.refreshTrendChart() // 触发图表重绘
                this.refreshBodyFatChart()
                promptAction.showToast({ message: '保存成功', duration: 1500 })
                this.showDateEditDialog = false
                this.editingRecord = null
                this.editDateText = ''
              })
          }
          .width('100%')
        }
        .width('100%')
      }
    }
    .width(320)
    .padding(24)
    .backgroundColor(AppColors.CARD)
    .borderRadius(20)
    .shadow({
      radius: 20,
      color: 'rgba(0,0,0,0.15)',
      offsetY: 6
    })
    .zIndex(13)
    .transition(
      TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.9, y: 0.9 }))
        .animation({ duration: 250, curve: Curve.EaseOut })
    )
  }

  // 编辑弹窗中的餐食选择组件
  @Builder
  EditMealSegment(onSelect: (index: number) => void, selectedIndex: number) {
    Row({ space: 8 }) {
      ForEach(['清淡', '正常', '放纵'], (label: string, index: number) => {
        Button(label)
          .fontSize(13)
          .fontColor(selectedIndex === index ? '#FFFFFF' : AppColors.TEXT_SECONDARY)
          .backgroundColor(selectedIndex === index ? AppColors.ACCENT : AppColors.BG)
          .layoutWeight(1)
          .height(36)
          .borderRadius(8)
          .onClick(() => {
            this.vibrateLight()
            onSelect(index)
          })
      })
    }
    .width('100%')
  }

  // 热力图日期编辑弹窗
  @Builder
  HeatmapEditDialog() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0,0,0,0.4)')
      .onClick(() => {
        this.heatmapVm?.closeEditDialog()
      })
      .zIndex(12)

    Column({ space: 16 }) {
      Text(this.heatmapVm?.editingRecord?.date ?? '')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)

      Divider().color(AppColors.DIVIDER)

      // 三餐选择
      Column({ space: 8 }) {
        Text('早餐')
          .fontSize(13)
          .fontColor(AppColors.TEXT_SECONDARY)
          .alignSelf(ItemAlign.Start)
        Row({ space: 8 }) {
          ForEach(['清淡', '正常', '放纵'], (label: string, index: number) => {
            Button(label)
              .fontSize(13)
              .fontColor(this.heatmapEditBreakfast === index ? '#FFFFFF' : AppColors.TEXT_SECONDARY)
              .backgroundColor(this.heatmapEditBreakfast === index ? AppColors.ACCENT : AppColors.BG)
              .layoutWeight(1)
              .height(36)
              .borderRadius(8)
              .onClick(() => {
                this.vibrateLight()
                this.heatmapEditBreakfast = index
              })
          })
        }
        .width('100%')
      }
      .width('100%')

      Column({ space: 8 }) {
        Text('午餐')
          .fontSize(13)
          .fontColor(AppColors.TEXT_SECONDARY)
          .alignSelf(ItemAlign.Start)
        Row({ space: 8 }) {
          ForEach(['清淡', '正常', '放纵'], (label: string, index: number) => {
            Button(label)
              .fontSize(13)
              .fontColor(this.heatmapEditLunch === index ? '#FFFFFF' : AppColors.TEXT_SECONDARY)
              .backgroundColor(this.heatmapEditLunch === index ? AppColors.ACCENT : AppColors.BG)
              .layoutWeight(1)
              .height(36)
              .borderRadius(8)
              .onClick(() => {
                this.vibrateLight()
                this.heatmapEditLunch = index
              })
          })
        }
        .width('100%')
      }
      .width('100%')

      Column({ space: 8 }) {
        Text('晚餐')
          .fontSize(13)
          .fontColor(AppColors.TEXT_SECONDARY)
          .alignSelf(ItemAlign.Start)
        Row({ space: 8 }) {
          ForEach(['清淡', '正常', '放纵'], (label: string, index: number) => {
            Button(label)
              .fontSize(13)
              .fontColor(this.heatmapEditDinner === index ? '#FFFFFF' : AppColors.TEXT_SECONDARY)
              .backgroundColor(this.heatmapEditDinner === index ? AppColors.ACCENT : AppColors.BG)
              .layoutWeight(1)
              .height(36)
              .borderRadius(8)
              .onClick(() => {
                this.vibrateLight()
                this.heatmapEditDinner = index
              })
          })
        }
        .width('100%')
      }
      .width('100%')

      Divider().color(AppColors.DIVIDER)

      // 体重体脂
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text('体重 (kg)')
            .fontSize(13)
            .fontColor(AppColors.TEXT_SECONDARY)
          TextInput({ text: this.heatmapEditWeightText, placeholder: '未填写' })
            .type(InputType.NUMBER_DECIMAL)
            .fontSize(15)
            .fontColor(AppColors.TEXT_PRIMARY)
            .backgroundColor(AppColors.BG)
            .height(44)
            .borderRadius(8)
            .textAlign(TextAlign.Center)
            .onChange((text: string) => {
              this.heatmapEditWeightText = text
            })
        }
        .layoutWeight(1)

        Column({ space: 4 }) {
          Text('体脂 (%)')
            .fontSize(13)
            .fontColor(AppColors.TEXT_SECONDARY)
          TextInput({ text: this.heatmapEditBodyFatText, placeholder: '未填写' })
            .type(InputType.NUMBER_DECIMAL)
            .fontSize(15)
            .fontColor(AppColors.TEXT_PRIMARY)
            .backgroundColor(AppColors.BG)
            .height(44)
            .borderRadius(8)
            .textAlign(TextAlign.Center)
            .onChange((text: string) => {
              this.heatmapEditBodyFatText = text
            })
        }
        .layoutWeight(1)
      }
      .width('100%')

      // 操作按钮
      Row({ space: 12 }) {
        Button('取消')
          .fontSize(14)
          .fontColor(AppColors.TEXT_SECONDARY)
          .backgroundColor(AppColors.BG)
          .layoutWeight(1)
          .height(44)
          .borderRadius(12)
          .onClick(() => {
            this.heatmapVm?.closeEditDialog()
            this.resetHeatmapEditState()
          })

        Button('保存')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor(AppColors.ACCENT)
          .layoutWeight(1)
          .height(44)
          .borderRadius(12)
          .onClick(async () => {
            this.vibrateLight()
            const weight = this.heatmapEditWeightText ? parseFloat(this.heatmapEditWeightText) : null
            const bodyFat = this.heatmapEditBodyFatText ? parseFloat(this.heatmapEditBodyFatText) : null

            const record: DailyRecord = {
              date: this.heatmapVm!.editingRecord!.date,
              breakfast: this.heatmapEditBreakfast >= 0 ? this.heatmapEditBreakfast : null,
              lunch: this.heatmapEditLunch >= 0 ? this.heatmapEditLunch : null,
              dinner: this.heatmapEditDinner >= 0 ? this.heatmapEditDinner : null,
              weight: weight,
              bodyFat: bodyFat
            }

            await this.vm?.dao.upsert(record)
            this.heatmapVm?.closeEditDialog()
            this.heatmapVm?.closeDetailDialog()
            // 刷新热力图
            this.heatmapVm?.loadMonth(this.heatmapVm.year, this.heatmapVm.month)
            this.resetHeatmapEditState()
            promptAction.showToast({ message: '保存成功', duration: 1500 })
          })
      }
      .width('100%')
    }
    .width(320)
    .padding(24)
    .backgroundColor(AppColors.CARD)
    .borderRadius(20)
    .shadow({
      radius: 20,
      color: 'rgba(0,0,0,0.15)',
      offsetY: 6
    })
    .zIndex(13)
    .position({ x: '50%', y: '50%' })
    .translate({ x: '-50%', y: '-50%' })
    .transition(
      TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.9, y: 0.9 }))
        .animation({ duration: 250, curve: Curve.EaseOut })
    )
  }

  // 重置热力图编辑状态
  private resetHeatmapEditState(): void {
    this.heatmapEditBreakfast = -1
    this.heatmapEditLunch = -1
    this.heatmapEditDinner = -1
    this.heatmapEditWeightText = ''
    this.heatmapEditBodyFatText = ''
  }

  // 初始化热力图编辑弹窗的状态
  private initHeatmapEditFromCell(): void {
    const cell = this.heatmapVm?.editingRecord
    if (cell) {
      this.heatmapEditBreakfast = cell.breakfast ?? -1
      this.heatmapEditLunch = cell.lunch ?? -1
      this.heatmapEditDinner = cell.dinner ?? -1
      this.heatmapEditWeightText = cell.weight !== null ? String(cell.weight) : ''
      this.heatmapEditBodyFatText = cell.bodyFat !== null ? String(cell.bodyFat) : ''
    }
  }
}
