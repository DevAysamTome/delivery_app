import 'package:delivery_app/views/login_views/login_view.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final List<String> images = ['assets/1.png', 'assets/2.png', 'assets/3.png'];

  final List<String> titles = [
    'مرحباً بكم في تطبيقنا',
    'استكشف المطاعم',
    'اطلب أكلتك المفضلة'
  ];

  final List<String> descriptions = [
    'تعرف على أطيب الأكلات من أكتر من 1000 مطعم',
    'تصفح القوائم وشوف شو الطبخات',
    'الأكل بيوصلك لباب بيتك بأسرع وقت'
  ];

  int _current = 0;
  final CarouselController _controller = CarouselController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image:
                    AssetImage('assets/bg.png'), // وضع مسار الصورة الخلفية هنا
                fit: BoxFit.cover,
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: CarouselSlider.builder(
                  itemCount: images.length,
                  carouselController: _controller,
                  itemBuilder:
                      (BuildContext context, int index, int realIndex) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          margin: const EdgeInsets.all(20),
                          child: Image.asset(
                            images[index],
                            fit: BoxFit.contain,
                            height: MediaQuery.of(context).size.height * 0.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          titles[index],
                          style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                              fontFamily: "Elmassry"),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            descriptions[index],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 28,
                                color: Colors.grey,
                                fontFamily: "Elmassry"),
                          ),
                        ),
                        const SizedBox(height: 30),
                        if (index == images.length - 1)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.fromLTRB(30, 15, 30, 15)),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => LoginScreen()),
                              );
                            },
                            child: const Text(
                              'Get Started',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 26),
                            ),
                          ),
                      ],
                    );
                  },
                  options: CarouselOptions(
                    height: MediaQuery.of(context).size.height * 0.85,
                    viewportFraction: 1.0,
                    enlargeCenterPage: true,
                    autoPlay: false,
                    enableInfiniteScroll: false,
                    onPageChanged: (index, reason) {
                      setState(() {
                        _current = index;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AnimatedSmoothIndicator(
                activeIndex: _current,
                count: images.length,
                effect: const WormEffect(
                  dotHeight: 15,
                  dotWidth: 15,
                  activeDotColor: Colors.redAccent,
                  dotColor: Colors.grey,
                ),
                onDotClicked: (index) {
                  _controller.animateToPage(index);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ],
      ),
    );
  }
}
